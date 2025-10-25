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
func ensureAuth(_ completion: @escaping () -> Void) {
    if Auth.auth().currentUser != nil {
        completion()
        return
    }
    Auth.auth().signInAnonymously { _, _ in completion() }
}

// MARK: - Tiny caches

private final class _ImageCache {
    static let shared = NSCache<NSString, PlatformImage>()
}

private final class _ResolvedURLCache {
    static let shared = NSCache<NSString, NSURL>()
}

enum StorageImageCache {
    static func invalidate(url: URL?) {
        guard let url else { return }
        invalidate(url: url)
    }

    static func invalidate(url: URL) {
        let absoluteKey = NSString(string: url.absoluteString)
        _ImageCache.shared.removeObject(forKey: absoluteKey)

        if let gsKey = _gsKey(for: url) {
            _ImageCache.shared.removeObject(forKey: gsKey)

            if let resolved = _ResolvedURLCache.shared.object(forKey: gsKey) {
                let resolvedKey = NSString(string: (resolved as URL).absoluteString)
                _ImageCache.shared.removeObject(forKey: resolvedKey)
            }

            _ResolvedURLCache.shared.removeObject(forKey: gsKey)
        }
    }

    static func invalidate(urls: [URL]) {
        urls.forEach { invalidate(url: $0) }
    }

    static func invalidateContestantAvatar(named assetName: String) {
        let trimmed = assetName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = StoragePaths.contestantAvatarURL(for: trimmed) else { return }
        invalidate(url: url)
    }

    static func invalidateUserAvatar(named assetName: String) {
        let trimmed = assetName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = StoragePaths.userAvatarURL(for: trimmed) else { return }
        invalidate(url: url)
    }
}

/// Normalizes a gs:// key like "gs://bucket/contestants/amanda_kimmel.jpg"
private func _gsKey(for url: URL) -> NSString? {
    guard url.scheme == "gs", let host = url.host else { return nil }
    let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    return NSString(string: "gs://\(host)/\(path)")
}


final class StorageImageLoader: ObservableObject {
    @Published var image: PlatformImage?
    @Published var error: Error?

    private var task: URLSessionDataTask?
    private var currentURL: URL?
    private var completion: ((Result<PlatformImage, Error>) -> Void)?

    func load(from url: URL, completion: ((Result<PlatformImage, Error>) -> Void)? = nil) {
        self.completion = completion

        if let cached = _ImageCache.shared.object(forKey: (url.absoluteString as NSString)) {
            self.image = cached
            self.currentURL = url
            complete(with: .success(cached))
            return
        }
        if let key = _gsKey(for: url),
           let cached = _ImageCache.shared.object(forKey: key) {
            self.image = cached
            self.currentURL = url
            complete(with: .success(cached))
            return
        }

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

    private func complete(with result: Result<PlatformImage, Error>) {
        guard let completion else { return }
        self.completion = nil
        DispatchQueue.main.async {
            completion(result)
        }
    }

    private func resolveAndFetch(from url: URL) {
        currentURL = url

        // ✅ Fast-path: reuse previously-resolved https for this gs://
        if let key = _gsKey(for: url),
           let mapped = _ResolvedURLCache.shared.object(forKey: key) {
            fetch(url: mapped as URL)
            return
        }

        // If it's already http(s), fetch directly
        if url.scheme?.hasPrefix("http") == true {
            fetch(url: url)
            return
        }

        // Must be gs://<bucket>/<object>
        guard url.scheme == "gs", let host = url.host else {
            setError(NSError(
                domain: "StorageImageLoader",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Unsupported URL: \(url)"]
            ))
            return
        }

        let bucket = "gs://\(host)"
        let objectPath = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        let storage = Storage.storage(url: bucket)
        let ref = storage.reference(withPath: objectPath)

        // 1) Try signed URL
        ref.downloadURL { [weak self] signedURL, downloadURLError in
            if let signedURL {
                // ✅ Remember gs -> https mapping
                if let key = _gsKey(for: url) {
                    _ResolvedURLCache.shared.setObject(signedURL as NSURL, forKey: key)
                }
                self?.fetch(url: signedURL)
                return
            }

            // 2) Try REST URL with token (from metadata)
            ref.getMetadata { metadata, metadataError in
                guard let self else { return }

                if let token = (metadata?.customMetadata?["firebaseStorageDownloadTokens"])
                    ?? (metadata?.dictionaryRepresentation()["downloadTokens"] as? String),
                   let downloadURL = self.restURL(host: host, objectPath: objectPath, token: token) {

                    // ✅ Remember gs -> https mapping
                    if let key = _gsKey(for: url) {
                        _ResolvedURLCache.shared.setObject(downloadURL as NSURL, forKey: key)
                    }
                    self.fetch(url: downloadURL)
                    return
                }

                // 3) Try REST URL without token (public object)
                if let downloadURL = self.restURL(host: host, objectPath: objectPath, token: nil) {
                    // ✅ Remember gs -> https mapping
                    if let key = _gsKey(for: url) {
                        _ResolvedURLCache.shared.setObject(downloadURL as NSURL, forKey: key)
                    }
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

                    // ✅ Cache by final https URL
                    _ImageCache.shared.setObject(image, forKey: (url.absoluteString as NSString))

                    // ✅ And by the original gs:// key (if any)
                    if let current = self.currentURL, let key = _gsKey(for: current) {
                        _ImageCache.shared.setObject(image, forKey: key)
                    }

                    self.complete(with: .success(image))
                } else {
                    let resolvedError = error ?? NSError(
                        domain: "StorageImageLoader",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to load image"]
                    )
                    self.error = resolvedError
                    self.complete(with: .failure(resolvedError))
                }
            }
        }
        task?.resume()
    }

    private func setError(_ error: Error?) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.task = nil
            let resolved = error ?? NSError(
                domain: "StorageImageLoader",
                code: -3,
                userInfo: [NSLocalizedDescriptionKey: "Unknown error"]
            )
            self.error = resolved
            self.complete(with: .failure(resolved))
        }
    }
}

final class StorageImagePrefetcher {
    static let shared = StorageImagePrefetcher()

    private let queue = DispatchQueue(label: "StorageImagePrefetcher")
    private var activeLoaders: [NSString: StorageImageLoader] = [:]

    func prefetch(urls: [URL]) {
        guard !urls.isEmpty else { return }

        queue.async { [weak self] in
            guard let self else { return }

            var seen = Set<String>()

            for url in urls {
                let absolute = url.absoluteString
                guard !absolute.isEmpty else { continue }

                let insertion = seen.insert(absolute)
                guard insertion.inserted else { continue }

                if self.isCached(url: url) {
                    continue
                }

                let key = NSString(string: absolute)
                if self.activeLoaders[key] != nil { continue }

                let loader = StorageImageLoader()
                self.activeLoaders[key] = loader

                DispatchQueue.main.async {
                    loader.load(from: url) { [weak self] _ in
                        guard let self else { return }
                        self.queue.async {
                            self.activeLoaders.removeValue(forKey: key)
                        }
                    }
                }
            }
        }
    }

    private func isCached(url: URL) -> Bool {
        if _ImageCache.shared.object(forKey: (url.absoluteString as NSString)) != nil {
            return true
        }

        if let key = _gsKey(for: url), _ImageCache.shared.object(forKey: key) != nil {
            return true
        }

        return false
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
