import CuantoCore
import Foundation
import SocialsCore
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Entry point for the iOS share sheet. Extracts whatever text/URLs/images the host app handed
/// over via `NSExtensionContext`, copies any attachment bytes into the App Group's shared
/// `share-attachments/` directory (so the host app can read them after this process exits), then
/// hands the extracted content to `ShareComposerViewModel`, which owns the caption + submit flow.
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        Task { [weak self] in
            await self?.presentComposer()
        }
    }

    private func presentComposer() async {
        let keychain = KeychainStore(
            service: "com.cuantolabs.socials.session",
            accessGroup: AppIdentifiers.keychainAccessGroup
        )
        let sessionStore = await SessionStore(
            keychain: keychain,
            refresh: { refreshToken in
                // The share extension never refreshes tokens itself — it only reads whatever
                // session state the host app last wrote to the shared Keychain. If a refresh is
                // ever attempted here (e.g. an expired access token), there's nothing to refresh
                // against, so surface it as signed-out rather than guessing at a network call.
                throw SocialsAPIError.unauthorized
            }
        )
        let handoffStore = AppGroupShareHandoffStore(
            containerURL: ExtensionEnvironment.sharedContainerURL)

        let extracted = await Self.extractSharedContent(
            from: extensionContext, attachmentsDirectory: handoffStore.attachmentsDirectory)

        let viewModel = ShareComposerViewModel(
            sessionStore: sessionStore,
            handoffStore: handoffStore,
            incomingURLs: extracted.urls,
            incomingAttachmentFilenames: extracted.attachmentFilenames
        )
        viewModel.caption = extracted.text

        let rootView = ShareComposerView(viewModel: viewModel) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        }
        let hostingController = UIHostingController(rootView: rootView)

        addChild(hostingController)
        hostingController.view.frame = view.bounds
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        hostingController.didMove(toParent: self)
    }

    struct ExtractedContent {
        var text: String = ""
        var urls: [String] = []
        var attachmentFilenames: [String] = []
    }

    /// Walks every `NSExtensionItem`/`NSItemProvider` the share sheet handed over. Images and
    /// movies get copied into `attachmentsDirectory` immediately (the extension's own sandbox is
    /// torn down once `completeRequest` runs, so nothing can be read lazily later); text and URLs
    /// are cheap enough to just collect.
    static func extractSharedContent(
        from extensionContext: NSExtensionContext?, attachmentsDirectory: URL?
    ) async -> ExtractedContent {
        var result = ExtractedContent()
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else { return result }

        for item in items {
            if let contentText = item.attributedContentText?.string, !contentText.isEmpty {
                result.text = result.text.isEmpty ? contentText : "\(result.text)\n\(contentText)"
            }
            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    if let url = await Self.loadURL(from: provider, typeIdentifier: UTType.url.identifier) {
                        result.urls.append(url.absoluteString)
                        continue
                    }
                }
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    if let text = await Self.loadText(from: provider), !text.isEmpty {
                        result.text = result.text.isEmpty ? text : "\(result.text)\n\(text)"
                        continue
                    }
                }
                if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    if let filename = await Self.copyFile(
                        from: provider, typeIdentifier: UTType.image.identifier,
                        into: attachmentsDirectory)
                    {
                        result.attachmentFilenames.append(filename)
                        continue
                    }
                }
                if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                    if let filename = await Self.copyFile(
                        from: provider, typeIdentifier: UTType.movie.identifier,
                        into: attachmentsDirectory)
                    {
                        result.attachmentFilenames.append(filename)
                    }
                }
            }
        }
        return result
    }

    private static func loadURL(from provider: NSItemProvider, typeIdentifier: String) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, _ in
                if let url = item as? URL {
                    continuation.resume(returning: url)
                } else if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private static func loadText(from provider: NSItemProvider) async -> String? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
                continuation.resume(returning: item as? String)
            }
        }
    }

    /// Loads the provider's file representation and copies it into `directory` under a fresh
    /// UUID-prefixed filename (so two attachments never collide), returning just the filename —
    /// `ShareHandoffItem.attachmentFilenames` only ever carries names, resolved against the App
    /// Group directory by whoever reads them next (the host app).
    private static func copyFile(
        from provider: NSItemProvider, typeIdentifier: String, into directory: URL?
    ) async -> String? {
        guard let directory else { return nil }
        return await withCheckedContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { sourceURL, _ in
                guard let sourceURL else {
                    continuation.resume(returning: nil)
                    return
                }
                let filename = "\(UUID().uuidString).\(sourceURL.pathExtension)"
                let destinationURL = directory.appendingPathComponent(filename)
                do {
                    try FileManager.default.createDirectory(
                        at: directory, withIntermediateDirectories: true)
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }
                    try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
                    continuation.resume(returning: filename)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
