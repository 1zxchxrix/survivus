import Foundation
import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseStorage
#if canImport(UIKit)
import UIKit
typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
typealias PlatformImage = NSImage
#endif

// Call this once in your App entry point (e.g., in your App init)
func configureFirebaseIfNeeded() {
    if FirebaseApp.app() == nil {
        FirebaseApp.configure()
    }
}

/// Ensure we have an auth user if rules require it (anonymous is fine)
func ensureAuth(_ completion: @escaping (Error?) -> Void) {
    if Auth.auth().currentUser != nil {
        completion(nil)
        return
    }

    Auth.auth().signInAnonymously { _, error in
        completion(error)
    }
}

final class StorageImageLoader: ObservableObject {
    @Published var image: PlatformImage?
    @Published var error: Error?

    private var task: URLSessionDataTask?
    private var currentURL: URL?

    func load(from url: URL) {
        if currentURL == url, image != nil {
            return
        }

        currentURL = url

        DispatchQueue.main.async { [weak self] in
            self?.image = nil
            self?.error = nil
        }

        let scheme = url.scheme?.lowercased()

        if scheme?.hasPrefix("http") == true {
            resolveAndFetch(from: url)
            return
        }

        guard scheme == "gs" else {
            resolveAndFetch(from: url)
            return
        }

        configureFirebaseIfNeeded()
        ensureAuth { [weak self] in
            self?.resolveAndFetch(from: url)
        }

        configureFirebaseIfNeeded()
        resolveAndFetch(from: url, attemptAuth: true)
    }

    func cancel() {
        task?.cancel()
        task = nil
    }

    func reset() {
        cancel()
        DispatchQueue.main.async { [weak self] in
            self?.image = nil
            self?.error = nil
            self?.currentURL = nil
        }
    }

    // MARK: - Core

    private func resolveAndFetch(from url: URL, attemptAuth: Bool) {
        currentURL = url

        if url.scheme?.hasPrefix("http") == true {
            fetch(url: url)
            return
        }

        guard url.scheme == "gs", let host = url.host else {
            setError(NSError(domain: "StorageImageLoader", code: -2,
                             userInfo: [NSLocalizedDescriptionKey: "Unsupported URL: \(url)"]))
            return
        }

        let bucket = "gs://\(host)"
        let objectPath = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        let storage = Storage.storage(url: bucket)
        let ref: StorageReference
        if objectPath.isEmpty {
            ref = storage.reference()
        } else {
            ref = storage.reference(withPath: objectPath)
        }

        ref.downloadURL { [weak self] signedURL, downloadURLError in
            guard let self else { return }

            if let signedURL {
                self.fetch(url: signedURL)
                return
            }

            if attemptAuth, self.shouldRetryAuth(for: downloadURLError) {
                self.retryWithAuth(for: url)
                return
            }

            ref.getMetadata { metadata, metadataError in
                guard let self else { return }

                if attemptAuth, self.shouldRetryAuth(for: metadataError) {
                    self.retryWithAuth(for: url)
                    return
                }

                if let token = (metadata?.customMetadata?["firebaseStorageDownloadTokens"])
                    ?? (metadata?.dictionaryRepresentation()["downloadTokens"] as? String),
                   let downloadURL = self.restURL(host: host, objectPath: objectPath, token: token) {
                    self.fetch(url: downloadURL)
                    return
                }

                if let downloadURL = self.restURL(host: host, objectPath: objectPath, token: nil) {
                    self.fetch(url: downloadURL)
                } else {
                    self.setError(metadataError ?? downloadURLError)
                }
            }
        }
    }

    private func restURL(host: String, objectPath: String, token: String?) -> URL? {
        let encodedPath = objectPath
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)?
            .replacingOccurrences(of: "/", with: "%2F") ?? objectPath

        var components = URLComponents()
        components.scheme = "https"
        components.host = "firebasestorage.googleapis.com"

        var percentEncodedPath = "/v0/b/\(host)/o"
        if !encodedPath.isEmpty {
            percentEncodedPath.append("/\(encodedPath)")
        }
        components.percentEncodedPath = percentEncodedPath

        var queryItems = [URLQueryItem(name: "alt", value: "media")]
        if let token = token?.split(separator: ",").first.map(String.init) {
            queryItems.append(URLQueryItem(name: "token", value: token))
        }
        components.queryItems = queryItems

        return components.url
    }

    private func fetch(url: URL) {
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 60)
        task?.cancel()
        task = URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.task = nil

                if let data, let image = PlatformImage(data: data) {
                    self.image = image
                } else {
                    self.error = error ?? NSError(
                        domain: "StorageImageLoader",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to load image"]
                    )
                }
            }
        }
        task?.resume()
    }

    private func setError(_ error: Error?) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.task = nil
            self.error = error ?? NSError(
                domain: "StorageImageLoader",
                code: -3,
                userInfo: [NSLocalizedDescriptionKey: "Unknown error"]
            )
        }
    }

    private func retryWithAuth(for url: URL) {
        ensureAuth { [weak self] authError in
            guard let self else { return }

            if let authError {
                self.setError(authError)
                return
            }

            if self.currentURL == url {
                self.resolveAndFetch(from: url, attemptAuth: false)
            }
        }
    }

    private func shouldRetryAuth(for error: Error?) -> Bool {
        guard let nsError = error as NSError?,
              nsError.domain == StorageErrorDomain,
              let code = StorageErrorCode(rawValue: nsError.code) else {
            return false
        }

        return code == .unauthenticated || code == .unauthorized
    }
}

public struct StorageAsyncImage<Content: View, Placeholder: View>: View {
    private let url: URL?
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder

    @StateObject private var loader = StorageImageLoader()

    public init(url: URL?,
                @ViewBuilder content: @escaping (Image) -> Content,
                @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }

    public var body: some View {
        Group {
            if let image = loader.image {
#if canImport(UIKit)
                content(Image(uiImage: image))
#elseif canImport(AppKit)
                content(Image(nsImage: image))
#endif
            } else {
                placeholder()
            }
        }
        .onAppear(perform: loadIfNeeded)
        .onChange(of: url?.absoluteString) { _ in
            loadIfNeeded()
        }
        .onDisappear {
            loader.cancel()
        }
    }

    private func loadIfNeeded() {
        guard let url else {
            loader.reset()
            return
        }

        loader.load(from: url)
    }
}
