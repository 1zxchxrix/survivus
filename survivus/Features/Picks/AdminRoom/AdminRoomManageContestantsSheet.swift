import SwiftUI
#if canImport(PhotosUI)
import PhotosUI
#endif
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
#if canImport(FirebaseStorage)
import FirebaseStorage
#endif

private struct AlertState: Identifiable {
    let id = UUID()
    let title: String
    let message: String?
}

struct ManageContestantsSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var contestants: [ContestantDraft]
    @State private var editMode: EditMode = .inactive
    @State private var isSaving = false
    @State private var alertState: AlertState?

    let onSave: ([Contestant]) -> Void

    init(contestants: [Contestant], onSave: @escaping ([Contestant]) -> Void) {
        _contestants = State(initialValue: contestants.map(ContestantDraft.init))
        self.onSave = onSave
    }

    private var duplicateIds: Set<String> {
        var seen: Set<String> = []
        var duplicates: Set<String> = []

        for id in contestants.map({ $0.normalizedIdentifier }).filter({ !$0.isEmpty }) {
            if !seen.insert(id).inserted {
                duplicates.insert(id)
            }
        }

        return duplicates
    }

    private var hasValidContestants: Bool {
        guard !contestants.contains(where: { $0.trimmedName.isEmpty || $0.trimmedIdentifier.isEmpty }) else {
            return false
        }
        return duplicateIds.isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if contestants.isEmpty {
                        ContentUnavailableView(
                            "No contestants",
                            systemImage: "person.2",
                            description: Text("Add contestants to configure the season.")
                        )
                        .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        ForEach($contestants) { contestant in
                            ContestantEditorRow(
                                contestant: contestant,
                                isDuplicateId: duplicateIds.contains(contestant.wrappedValue.normalizedIdentifier),
                                onAvatarError: { message in
                                    alertState = AlertState(
                                        title: "Avatar Error",
                                        message: message
                                    )
                                }
                            )
                        }
                        .onDelete(perform: deleteContestants)
                        .onMove(perform: moveContestants)
                    }
                } header: {
                    Text("Contestants")
                } footer: {
                    Text("Identifiers are used for scoring and should remain stable once picks are recorded.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button {
                        withAnimation(.easeInOut) {
                            contestants.append(ContestantDraft())
                        }
                    } label: {
                        Label("Add contestant", systemImage: "plus.circle.fill")
                    }
                }
            }
            .environment(\.editMode, $editMode)
            .animation(.easeInOut, value: contestants)
            .navigationTitle("Manage Contestants")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: saveContestants) {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(!hasValidContestants || isSaving)
                }
                ToolbarItem(placement: .primaryAction) {
                    EditButton()
                }
            }
            .alert(item: $alertState) { alert in
                Alert(
                    title: Text(alert.title),
                    message: alert.message.map(Text.init),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    private func saveContestants() {
        Task {
            await performSave()
        }
    }

    private func performSave() async {
        await MainActor.run {
            isSaving = true
        }

        do {
            let updated = try await uploadAvatarsAndBuildContestants()
            await MainActor.run {
                onSave(updated)
                dismiss()
            }
        } catch {
            await MainActor.run {
                alertState = AlertState(
                    title: "Unable to Save",
                    message: error.localizedDescription
                )
            }
        }

        await MainActor.run {
            isSaving = false
        }
    }

    private func uploadAvatarsAndBuildContestants() async throws -> [Contestant] {
        let drafts = await MainActor.run { contestants }
        var updatedDrafts = drafts

        for index in updatedDrafts.indices {
            guard let imageData = updatedDrafts[index].avatarImageData else { continue }
            let assetName = updatedDrafts[index].uploadAssetName
            let normalized = try await ContestantAvatarUploader.uploadAvatar(
                data: imageData,
                assetName: assetName
            )
            updatedDrafts[index].avatarAssetName = normalized
            updatedDrafts[index].avatarImageData = nil
        }

        await MainActor.run {
            contestants = updatedDrafts
        }

        return updatedDrafts.map { $0.makeContestant() }
    }

    private func deleteContestants(at offsets: IndexSet) {
        withAnimation(.easeInOut) {
            contestants.remove(atOffsets: offsets)
        }
    }

    private func moveContestants(from source: IndexSet, to destination: Int) {
        contestants.move(fromOffsets: source, toOffset: destination)
    }
}

#Preview("Manage Contestants Sheet") {
    ManageContestantsSheet(contestants: AppState.preview.store.config.contestants) { _ in }
}

private struct ContestantEditorRow: View {
    @Binding var contestant: ContestantDraft
    var isDuplicateId: Bool
    var onAvatarError: (String) -> Void

    @State private var selectedItem: PhotosPickerItem?

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            avatarPicker

            VStack(alignment: .leading, spacing: 12) {
                TextField("Display name", text: Binding(
                    get: { contestant.name },
                    set: { newValue in contestant.updateName(newValue) }
                ))
                .textContentType(.name)

                TextField("Identifier", text: Binding(
                    get: { contestant.identifier },
                    set: { newValue in contestant.updateIdentifier(newValue) }
                ))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)

                TextField("Tribe (optional)", text: Binding(
                    get: { contestant.tribe },
                    set: { contestant.tribe = $0 }
                ))

                if contestant.trimmedName.isEmpty {
                    validationMessage("Name is required")
                }

                if contestant.trimmedIdentifier.isEmpty {
                    validationMessage("Identifier is required")
                } else if isDuplicateId {
                    validationMessage("Identifier must be unique")
                }
            }
        }
        .padding(.vertical, 8)
        .onChange(of: selectedItem) { newValue in
            guard let newValue else { return }
            Task {
                await handleSelection(newValue)
            }
        }
    }

    private var avatarPicker: some View {
        PhotosPicker(selection: $selectedItem, matching: .images) {
            ContestantAvatarPreview(
                imageData: contestant.avatarImageData,
                assetName: contestant.trimmedAvatarAssetName,
                fallbackIdentifier: contestant.normalizedIdentifier
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Change avatar"))
        .contextMenu {
            Button("Remove Avatar", role: .destructive) {
                contestant.avatarImageData = nil
                contestant.avatarAssetName = nil
            }
        }
    }

    private func handleSelection(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                onAvatarError("Unable to load the selected image.")
                return
            }

            guard let normalized = normalizeAvatarImageData(data) else {
                onAvatarError("The selected image could not be processed.")
                return
            }

            await MainActor.run {
                contestant.avatarImageData = normalized
                selectedItem = nil
            }
        } catch {
            onAvatarError(error.localizedDescription)
            await MainActor.run {
                selectedItem = nil
            }
        }
    }

    @ViewBuilder
    private func validationMessage(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(Color.red)
    }
}

private func normalizeAvatarImageData(_ data: Data) -> Data? {
#if canImport(UIKit)
    guard let image = UIImage(data: data) else { return nil }
    let maxDimension: CGFloat = 512
    let maxSide = max(image.size.width, image.size.height)
    let scale = maxSide > maxDimension ? maxDimension / maxSide : 1
    let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

    UIGraphicsBeginImageContextWithOptions(targetSize, false, 1)
    image.draw(in: CGRect(origin: .zero, size: targetSize))
    let scaled = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()

    let finalImage = scaled ?? image
    return finalImage.jpegData(compressionQuality: 0.85)
#elseif canImport(AppKit)
    guard let image = NSImage(data: data) else { return nil }
    let resized = image.resized(toMaxDimension: 512)
    guard let tiff = resized.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
    return bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.85])
#else
    return data
#endif
}

#if canImport(AppKit)
private extension NSImage {
    func resized(toMaxDimension maxDimension: CGFloat) -> NSImage {
        guard maxDimension > 0 else { return self }
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else { return self }

        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        defer { newImage.unlockFocus() }

        guard let context = NSGraphicsContext.current else { return self }
        context.imageInterpolation = .high

        draw(
            in: CGRect(origin: .zero, size: newSize),
            from: CGRect(origin: .zero, size: size),
            operation: .copy,
            fraction: 1.0
        )

        return newImage
    }
}
#endif

private struct ContestantAvatarPreview: View {
    var imageData: Data?
    var assetName: String?
    var fallbackIdentifier: String

    private let size: CGFloat = 64

    var body: some View {
        avatarContent
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .strokeBorder(Color.secondary.opacity(0.25), lineWidth: 1)
            )
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "camera.fill")
                    .font(.footnote)
                    .padding(6)
                    .background(.thinMaterial, in: Circle())
                    .offset(x: 2, y: 2)
            }
    }

    @ViewBuilder
    private var avatarContent: some View {
        if let data = imageData, let image = platformImage(from: data) {
            image
                .resizable()
                .scaledToFill()
        } else if let url = remoteURL {
            StorageAsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                placeholder
            }
        } else {
            placeholder
        }
    }

    private var remoteURL: URL? {
        let candidate = (assetName?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
            ?? fallbackIdentifier
        guard !candidate.isEmpty else { return nil }
        return StoragePaths.contestantAvatarURL(for: candidate)
    }

    private var placeholder: some View {
        ZStack {
            Color.secondary.opacity(0.12)
            Image(systemName: "person.fill")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private func platformImage(from data: Data) -> Image? {
        #if canImport(UIKit)
        guard let uiImage = UIImage(data: data) else { return nil }
        return Image(uiImage: uiImage)
        #elseif canImport(AppKit)
        guard let nsImage = NSImage(data: data) else { return nil }
        return Image(nsImage: nsImage)
        #else
        return nil
        #endif
    }
}

private struct ContestantDraft: Identifiable, Equatable {
    let id: UUID
    private(set) var hasCustomIdentifier: Bool

    var identifier: String
    var name: String
    var tribe: String
    var avatarAssetName: String?
    var avatarImageData: Data?

    init(
        id: UUID = UUID(),
        identifier: String = "",
        name: String = "",
        tribe: String = "",
        avatarAssetName: String? = nil,
        avatarImageData: Data? = nil,
        hasCustomIdentifier: Bool = false
    ) {
        self.id = id
        self.identifier = identifier
        self.name = name
        self.tribe = tribe
        self.avatarAssetName = avatarAssetName
        self.avatarImageData = avatarImageData
        self.hasCustomIdentifier = hasCustomIdentifier
    }

    init(_ contestant: Contestant) {
        self.init(
            identifier: contestant.id,
            name: contestant.name,
            tribe: contestant.tribe ?? "",
            avatarAssetName: contestant.avatarAssetName,
            avatarImageData: nil,
            hasCustomIdentifier: true
        )
    }

    mutating func updateName(_ newValue: String) {
        name = newValue
        guard !hasCustomIdentifier else { return }
        identifier = Self.slug(from: newValue)
    }

    mutating func updateIdentifier(_ newValue: String) {
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        identifier = newValue
        hasCustomIdentifier = !trimmed.isEmpty
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedIdentifier: String {
        identifier.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedIdentifier: String {
        trimmedIdentifier.lowercased()
    }

    var trimmedTribe: String? {
        let trimmed = tribe.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var trimmedAvatarAssetName: String? {
        guard let avatarAssetName else { return nil }
        let trimmed = avatarAssetName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var uploadAssetName: String {
        let candidate = trimmedAvatarAssetName ?? trimmedIdentifier
        if let url = URL(string: candidate), url.scheme != nil {
            return normalizedIdentifier
        }

        var sanitized = candidate
        while sanitized.hasPrefix("/") { sanitized.removeFirst() }
        sanitized = sanitized.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        return sanitized.isEmpty ? normalizedIdentifier : sanitized
    }

    func makeContestant() -> Contestant {
        Contestant(
            id: trimmedIdentifier,
            name: trimmedName,
            tribe: trimmedTribe,
            avatarAssetName: trimmedAvatarAssetName ?? trimmedIdentifier
        )
    }

    private static func slug(from text: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let components = text.lowercased().components(separatedBy: allowed.inverted)
        let filtered = components.filter { !$0.isEmpty }
        return filtered.joined(separator: "_")
    }
}

private enum ContestantAvatarUploader {
    enum UploadError: LocalizedError {
        case invalidAssetName
        case storageUnavailable

        var errorDescription: String? {
            switch self {
            case .invalidAssetName:
                return "The contestant needs a valid identifier before an avatar can be uploaded."
            case .storageUnavailable:
                return "Firebase Storage is not available in this build configuration."
            }
        }
    }

    static func uploadAvatar(data: Data, assetName: String) async throws -> String {
        let normalized = normalizeAssetName(assetName)
        guard !normalized.isEmpty else {
            throw UploadError.invalidAssetName
        }

#if canImport(FirebaseStorage)
        return try await withCheckedThrowingContinuation { continuation in
            configureFirebaseIfNeeded()
            ensureAuth {
                Task {
                    do {
                        let storage = Storage.storage(url: StoragePaths.bucket)
                        let reference = storage.reference(withPath: storagePath(for: normalized))
                        let metadata = StorageMetadata()
                        metadata.contentType = "image/jpeg"
                        _ = try await reference.putDataAsync(data, metadata: metadata)
                        StorageImageCache.invalidateContestantAvatar(named: normalized)
                        continuation.resume(returning: normalized)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
#else
        throw UploadError.storageUnavailable
#endif
    }

    private static func normalizeAssetName(_ name: String) -> String {
        var trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), let scheme = url.scheme, !scheme.isEmpty {
            trimmed = url.lastPathComponent
        }

        while trimmed.hasPrefix("/") { trimmed.removeFirst() }

        if trimmed.hasPrefix("contestants/") {
            trimmed.removeFirst("contestants/".count)
        }

        trimmed = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return trimmed
    }

    private static func storagePath(for normalized: String) -> String {
        var path = "contestants/\(normalized)"
        if normalized.split(separator: "/").last?.contains(".") == true {
            return path
        }
        path.append(".jpg")
        return path
    }
}
