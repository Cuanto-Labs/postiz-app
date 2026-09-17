import Foundation
import Observation

/// Post detail: status timeline, retry, preview link, comments, statistics. Lives in
/// `SocialsCore` so it's testable with `StubSocialsAPI`, mirroring `ChannelsViewModel`/
/// `CalendarViewModel`. Web has no single "post detail" component to mirror 1:1 — this composes
/// the same server endpoints the web launches UI hits separately (`statistics.tsx`,
/// `comments/comment.component.tsx`, the post-group fetch, and reschedule).
@MainActor
@Observable
public final class PostDetailViewModel {
    public let postId: String

    public private(set) var post: PostGroupDTO?
    public private(set) var statusTimeline: PostStatusTimeline?
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?

    public private(set) var isRetrying = false

    public private(set) var previewPosts: [PostGroupDTO] = []
    public private(set) var isLoadingPreview = false

    public private(set) var comments: [PostCommentDTO] = []
    public private(set) var isLoadingComments = false
    public private(set) var isAddingComment = false

    public private(set) var statistics: OpaqueJSONResult?
    public private(set) var isLoadingStatistics = false

    private let api: any SocialsAPI

    public init(postId: String, api: any SocialsAPI) {
        self.postId = postId
        self.api = api
    }

    // MARK: - Detail + status timeline

    public func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let result = try await api.post(group: postId)
            post = result
            statusTimeline = PostStatusTimeline(current: PostStatusStep(rawStatus: result.status))
        } catch let error as SocialsAPIError {
            errorMessage = Self.message(for: error)
        } catch {
            errorMessage = "Something went wrong. Please try again."
        }
    }

    // MARK: - Retry

    /// Retries a failed post. No dedicated retry endpoint exists in the mobile API (checked
    /// `mobile-posts.controller.ts` and every `launches/` web component — only provider-level
    /// retry logic exists, unrelated to this action) — `reschedule(action: "schedule")` at the
    /// current time is the closest available mechanism, mirroring how a requeue is expressed
    /// elsewhere in this API. Only meaningful from `.failed`; no-ops otherwise.
    public func retry() async {
        guard let timeline = statusTimeline, timeline.isFailed else { return }
        isRetrying = true
        errorMessage = nil
        defer { isRetrying = false }
        do {
            _ = try await api.reschedule(group: postId, date: Self.iso(.now), action: "schedule")
            await load()
        } catch let error as SocialsAPIError {
            errorMessage = Self.message(for: error)
        } catch {
            errorMessage = "Something went wrong. Please try again."
        }
    }

    // MARK: - Preview link

    public func loadPreview() async {
        isLoadingPreview = true
        errorMessage = nil
        defer { isLoadingPreview = false }
        do {
            let response = try await api.preview(id: postId)
            previewPosts = response.posts
        } catch let error as SocialsAPIError {
            errorMessage = Self.message(for: error)
        } catch {
            errorMessage = "Something went wrong. Please try again."
        }
    }

    // MARK: - Comments

    public func loadComments() async {
        isLoadingComments = true
        errorMessage = nil
        defer { isLoadingComments = false }
        do {
            let response = try await api.comments(id: postId)
            comments = response.comments
        } catch let error as SocialsAPIError {
            errorMessage = Self.message(for: error)
        } catch {
            errorMessage = "Something went wrong. Please try again."
        }
    }

    /// Adds a comment and prepends it locally (mirrors web's `comment.component.tsx`
    /// `addComment`, which appends the created row to local state rather than refetching).
    public func addComment(_ text: String) async {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isAddingComment = true
        errorMessage = nil
        defer { isAddingComment = false }
        do {
            let created = try await api.addComment(id: postId, comment: text)
            comments.insert(created, at: 0)
        } catch let error as SocialsAPIError {
            errorMessage = Self.message(for: error)
        } catch {
            errorMessage = "Something went wrong. Please try again."
        }
    }

    // MARK: - Statistics

    public func loadStatistics() async {
        isLoadingStatistics = true
        errorMessage = nil
        defer { isLoadingStatistics = false }
        do {
            statistics = try await api.statistics(id: postId)
        } catch let error as SocialsAPIError {
            errorMessage = Self.message(for: error)
        } catch {
            errorMessage = "Something went wrong. Please try again."
        }
    }

    // MARK: - Error mapping

    private static func iso(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private static func message(for error: SocialsAPIError) -> String {
        switch error {
        case .unauthorized: return "Your session expired. Please sign in again."
        case .offline: return "You're offline. Check your connection and try again."
        case .forbidden(let message): return message ?? "That action isn't allowed."
        case .validation(let message): return message ?? "Check your details and try again."
        case .notFound: return "That couldn't be found."
        case .server, .idempotencyConflict, .aiNotInPlan, .aiCreditsExhausted:
            return "Something went wrong. Please try again."
        case .aiConsentRequired:
            return "AI text suggestions need your consent first."
        case .cancelled: return ""
        }
    }
}
