import Foundation

/// One shared item queued by the Share extension for the host app to finish next launch. The
/// extension has no channel picker, no upload flow, and a tiny memory budget, so its job is
/// deliberately dumb: capture whatever came in from `NSExtensionContext`, write it somewhere the
/// host app's process can read it, done. `T171`+ (a later card) is what turns this into an
/// actual post via `SocialsAPI.createPost`.
public struct ShareHandoffItem: Sendable, Equatable, Identifiable, Codable {
    public let id: String
    public let createdAt: Date
    public var text: String
    public var urls: [String]
    /// Filenames (not full paths) of any images/video copied into
    /// `ShareHandoffStoring.attachmentsDirectory` — resolved against that directory by the
    /// reader, since the extension's and the host app's container path can differ.
    public var attachmentFilenames: [String]

    public init(
        id: String = UUID().uuidString, createdAt: Date = Date(), text: String = "",
        urls: [String] = [], attachmentFilenames: [String] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.text = text
        self.urls = urls
        self.attachmentFilenames = attachmentFilenames
    }

    public var isEmpty: Bool { text.isEmpty && urls.isEmpty && attachmentFilenames.isEmpty }
}

/// Persists the inbox of `ShareHandoffItem`s across the App Group boundary: the Share extension
/// `enqueue`s, the host app later `pendingItems()`/`remove(id:)`s. Conformers own where
/// attachment bytes live — `attachmentFilenames` only ever carries relative names.
public protocol ShareHandoffStoring: Sendable {
    func enqueue(_ item: ShareHandoffItem) throws
    func pendingItems() throws -> [ShareHandoffItem]
    func remove(id: String) throws
    /// Directory attachment files should be copied into/read from; `nil` when there's no
    /// writable container (e.g. App Group entitlement misconfigured).
    var attachmentsDirectory: URL? { get }
}

public enum ShareHandoffError: Error, Sendable, Equatable {
    case noContainer
}

/// App-Group-backed `ShareHandoffStoring`: a `share-inbox.json` index next to a
/// `share-attachments/` subdirectory, both inside the shared container, so the Share
/// extension's write and the host app's read cross the process boundary via the filesystem
/// rather than IPC (extensions and the host app never run simultaneously in a way that lets
/// them talk directly).
public final class AppGroupShareHandoffStore: ShareHandoffStoring, @unchecked Sendable {
    private let containerURL: URL?
    private let indexFilename: String
    private let lock = NSLock()

    public init(containerURL: URL?, indexFilename: String = "share-inbox.json") {
        self.containerURL = containerURL
        self.indexFilename = indexFilename
        if let dir = attachmentsDirectory {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    public var attachmentsDirectory: URL? {
        containerURL?.appendingPathComponent("share-attachments", isDirectory: true)
    }

    private var indexURL: URL? {
        containerURL?.appendingPathComponent(indexFilename)
    }

    public func enqueue(_ item: ShareHandoffItem) throws {
        lock.lock()
        defer { lock.unlock() }
        guard let indexURL else { throw ShareHandoffError.noContainer }
        var items = readAll(at: indexURL)
        items.append(item)
        try JSONEncoder().encode(items).write(to: indexURL, options: .atomic)
    }

    public func pendingItems() throws -> [ShareHandoffItem] {
        lock.lock()
        defer { lock.unlock() }
        guard let indexURL else { throw ShareHandoffError.noContainer }
        return readAll(at: indexURL)
    }

    public func remove(id: String) throws {
        lock.lock()
        defer { lock.unlock() }
        guard let indexURL else { throw ShareHandoffError.noContainer }
        var items = readAll(at: indexURL)
        items.removeAll { $0.id == id }
        try JSONEncoder().encode(items).write(to: indexURL, options: .atomic)
    }

    private func readAll(at url: URL) -> [ShareHandoffItem] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([ShareHandoffItem].self, from: data)) ?? []
    }
}

/// In-memory `ShareHandoffStoring` for tests/previews — no App Group container involved.
public final class InMemoryShareHandoffStore: ShareHandoffStoring, @unchecked Sendable {
    public private(set) var items: [ShareHandoffItem]
    public var attachmentsDirectory: URL?
    public var enqueueError: Error?

    public init(items: [ShareHandoffItem] = [], attachmentsDirectory: URL? = nil) {
        self.items = items
        self.attachmentsDirectory = attachmentsDirectory
    }

    public func enqueue(_ item: ShareHandoffItem) throws {
        if let enqueueError { throw enqueueError }
        items.append(item)
    }

    public func pendingItems() throws -> [ShareHandoffItem] { items }
    public func remove(id: String) throws { items.removeAll { $0.id == id } }
}
