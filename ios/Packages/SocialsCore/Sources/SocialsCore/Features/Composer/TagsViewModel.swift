import Foundation
import Observation

/// Tags list (create/edit/delete) + per-post tag picks, mirrors web's
/// `apps/frontend/src/components/launches/tags.component.tsx`: a shared org tag list fetched via
/// `GET /tags`, with add/edit/delete driving `POST`/`PUT`/`DELETE /tags/:id`, and picking tags for
/// the current post building the `{ value, label }` pairs `CreatePostBody.tags` expects.
@MainActor
@Observable
public final class TagsViewModel {
    public private(set) var tags: [TagDTO] = []
    public private(set) var selectedTagIds: Set<String> = []
    public private(set) var isLoading = false
    public private(set) var isSaving = false
    public private(set) var errorMessage: String?

    private let api: any SocialsAPI

    public init(api: any SocialsAPI) {
        self.api = api
    }

    // MARK: - List

    public func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let response = try await api.tags()
            tags = response.tags
            let validIds = Set(tags.map(\.id))
            selectedTagIds = selectedTagIds.filter { validIds.contains($0) }
        } catch let error as SocialsAPIError {
            errorMessage = Self.message(for: error)
        } catch {
            errorMessage = "Something went wrong. Please try again."
        }
    }

    // MARK: - Selection (per-post picks)

    public func isSelected(_ tag: TagDTO) -> Bool { selectedTagIds.contains(tag.id) }

    /// Toggles a tag pick, mirrors web's picker click handler in `TagsComponentInner`.
    public func toggleSelection(_ tag: TagDTO) {
        if selectedTagIds.contains(tag.id) {
            selectedTagIds.remove(tag.id)
        } else {
            selectedTagIds.insert(tag.id)
        }
    }

    public var selectedTags: [TagDTO] { tags.filter { selectedTagIds.contains($0.id) } }

    /// `PostTagRef` list for `ComposerViewModel.submit(tags:)`, mirrors web's `onChange` payload
    /// shape (`{ value: name, label: name }`).
    public var selectedTagRefs: [PostTagRef] {
        selectedTags.map { PostTagRef(value: $0.name, label: $0.name) }
    }

    // MARK: - CRUD

    /// Creates a tag and selects it, mirrors web's `addTag` (a tag created from the modal is
    /// auto-appended to the current selection).
    @discardableResult
    public func createTag(name: String, color: String) async -> Bool {
        await withReload {
            let tag = try await self.api.createTag(CreateTagRequest(name: name, color: color))
            self.selectedTagIds.insert(tag.id)
        }
    }

    @discardableResult
    public func updateTag(_ tag: TagDTO, name: String, color: String) async -> Bool {
        await withReload {
            _ = try await self.api.updateTag(
                tag.id, body: CreateTagRequest(name: name, color: color))
        }
    }

    /// Deletes a tag and drops it from the current selection, mirrors web's `deleteTag`.
    @discardableResult
    public func deleteTag(_ tag: TagDTO) async -> Bool {
        await withReload {
            _ = try await self.api.deleteTag(tag.id)
            self.selectedTagIds.remove(tag.id)
        }
    }

    private func withReload(_ operation: @escaping () async throws -> Void) async -> Bool {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await operation()
            await load()
            return true
        } catch let error as SocialsAPIError {
            errorMessage = Self.message(for: error)
            return false
        } catch {
            errorMessage = "Something went wrong. Please try again."
            return false
        }
    }

    private static func message(for error: SocialsAPIError) -> String {
        switch error {
        case .offline: return "You're offline. Check your connection and try again."
        case .validation(let message): return message ?? "Check your details and try again."
        case .forbidden(let message): return message ?? "That action isn't available right now."
        case .notFound: return "That tag couldn't be found."
        case .cancelled: return ""
        default: return "Something went wrong. Please try again."
        }
    }
}
