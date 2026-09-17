import Foundation
import Observation

/// Calendar display mode, mirroring web's `ICalendarType` (`calendar.context.tsx`). `.list`
/// switches the view model off date-window fetching (`posts`) onto paginated fetching
/// (`postsList`), matching the web calendar/list SWR key split.
public enum CalendarDisplay: String, Sendable, Equatable, CaseIterable {
    case day
    case week
    case month
    case list
}

/// Calendar posts: day/week/month grid ranges + list pagination, customer filter, `CacheStore`
/// read-through for grid views (instant paint from cache while the network fetch is in flight),
/// and refresh. Lives in `SocialsCore` so it's testable with `StubSocialsAPI` + an in-memory
/// `CacheStore`, mirroring `OrgSwitcherViewModel`/`ChannelsViewModel`.
@MainActor
@Observable
public final class CalendarViewModel {
    public private(set) var display: CalendarDisplay
    public private(set) var referenceDate: Date
    public private(set) var customer: String?
    public private(set) var posts: [PostGroupDTO] = []
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?

    // MARK: - List mode

    public private(set) var listPosts: [PostListItemDTO] = []
    public private(set) var listPage = 0
    public private(set) var listTotal = 0
    public var listTotalPages: Int {
        listTotal > 0 ? Int((Double(listTotal) / 100).rounded(.up)) : 0
    }

    private let api: any SocialsAPI
    private let cacheStore: CacheStore
    private let orgId: String

    public init(
        api: any SocialsAPI,
        cacheStore: CacheStore,
        orgId: String,
        display: CalendarDisplay = .week,
        referenceDate: Date = .now
    ) {
        self.api = api
        self.cacheStore = cacheStore
        self.orgId = orgId
        self.display = display
        self.referenceDate = referenceDate
    }

    // MARK: - Filters

    /// Switches display mode and reloads (mirrors web's `setFiltersWrapper`, which resets to
    /// page 0 when switching into `.list`).
    public func setDisplay(_ display: CalendarDisplay) async {
        self.display = display
        if display == .list {
            listPage = 0
        }
        await refresh()
    }

    public func setReferenceDate(_ date: Date) async {
        referenceDate = date
        guard display != .list else { return }
        await refresh()
    }

    public func setCustomer(_ customer: String?) async {
        self.customer = customer
        await refresh()
    }

    // MARK: - Load

    /// Reloads whichever mode is active — grid (day/week/month) or list.
    public func refresh() async {
        if display == .list {
            await loadList()
        } else {
            await loadGrid()
        }
    }

    public func nextListPage() async {
        listPage += 1
        await loadList()
    }

    public func previousListPage() async {
        guard listPage > 0 else { return }
        listPage -= 1
        await loadList()
    }

    private func loadGrid() async {
        guard let window = CalendarRange.range(for: display, referenceDate: referenceDate) else { return }
        errorMessage = nil

        // Cache read-through: paint from cache immediately (customer filter isn't cached, so
        // skip it there — mirrors the grid always fetching from network when filtered).
        if customer == nil, let cached = try? await cacheStore.posts(orgId: orgId, in: window) {
            posts = cached.compactMap { try? JSONDecoder().decode(PostGroupDTO.self, from: $0.rawJSON) }
        }

        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await api.posts(
                from: Self.iso(window.lowerBound), to: Self.iso(window.upperBound), customer: customer)
            posts = response.posts
            if customer == nil {
                try? await cacheStore.upsertPosts(response.posts, orgId: orgId, window: window)
            }
        } catch let error as SocialsAPIError {
            errorMessage = Self.message(for: error)
        } catch {
            errorMessage = "Something went wrong. Please try again."
        }
    }

    private func loadList() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await api.postsList(page: listPage, limit: 100)
            listPosts = response.posts
            listTotal = response.total ?? listPosts.count
        } catch let error as SocialsAPIError {
            errorMessage = Self.message(for: error)
        } catch {
            errorMessage = "Something went wrong. Please try again."
        }
    }

    // MARK: - Reschedule (optimistic + rollback)

    public private(set) var isRescheduling = false

    /// Drag-to-reschedule: updates `posts` immediately so the grid moves the card before the
    /// network round trip, then confirms via `api.reschedule`. Rolls the local mutation back
    /// and surfaces `errorMessage` on failure — mirrors web's `calendar.tsx` drag handler,
    /// which optimistically moves the card and reverts on a failed `PUT`.
    @discardableResult
    public func reschedule(group: String, to date: Date) async -> Bool {
        guard let index = posts.firstIndex(where: { $0.group == group }) else { return false }
        let previous = posts[index]
        let iso = Self.iso(date)
        posts[index] = PostGroupDTO(
            id: previous.id, group: previous.group, publishDate: iso, status: previous.status,
            integration: previous.integration, content: previous.content)
        isRescheduling = true
        errorMessage = nil
        defer { isRescheduling = false }
        do {
            _ = try await api.reschedule(group: group, date: iso, action: nil)
            return true
        } catch let error as SocialsAPIError {
            posts[index] = previous
            errorMessage = Self.message(for: error)
            return false
        } catch {
            posts[index] = previous
            errorMessage = "Something went wrong. Please try again."
            return false
        }
    }

    // MARK: - Duplicate

    public private(set) var isDuplicating = false

    /// Duplicates a post group by re-creating it with the same content and time, mirrors
    /// web's `calendar.tsx` duplicate action (`editPost(post, true)`, which prefills the
    /// editor from the original and submits a fresh `POST /posts`). Appends the created
    /// group locally so the grid reflects it without a full refetch.
    public func duplicate(_ post: PostGroupDTO) async {
        isDuplicating = true
        errorMessage = nil
        defer { isDuplicating = false }
        do {
            let created = try await api.createPost(
                body: CreatePostBody(type: "now", posts: [post], date: post.publishDate),
                key: nil)
            posts.append(created)
        } catch let error as SocialsAPIError {
            errorMessage = Self.message(for: error)
        } catch {
            errorMessage = "Something went wrong. Please try again."
        }
    }

    // MARK: - Delete

    public private(set) var isDeleting = false

    /// Deletes a post group and removes it from whichever mode is active locally, mirrors
    /// `PostDetailViewModel.delete()` plus web's `calendar.tsx` `deletePost` list removal.
    public func delete(group: String) async {
        isDeleting = true
        errorMessage = nil
        defer { isDeleting = false }
        do {
            _ = try await api.deletePost(group: group)
            posts.removeAll { $0.group == group }
            listPosts.removeAll { $0.group == group }
        } catch let error as SocialsAPIError {
            errorMessage = Self.message(for: error)
        } catch {
            errorMessage = "Something went wrong. Please try again."
        }
    }

    // MARK: - Preview

    public private(set) var previewPosts: [PostGroupDTO] = []
    public private(set) var isLoadingPreview = false

    /// Loads the shareable preview for a post group, mirrors `PostDetailViewModel.loadPreview()`.
    public func loadPreview(group: String) async {
        isLoadingPreview = true
        errorMessage = nil
        defer { isLoadingPreview = false }
        do {
            let response = try await api.preview(id: group)
            previewPosts = response.posts
        } catch let error as SocialsAPIError {
            errorMessage = Self.message(for: error)
        } catch {
            errorMessage = "Something went wrong. Please try again."
        }
    }

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
        case .server, .idempotencyConflict, .aiNotInPlan, .aiCreditsExhausted, .aiConsentRequired:
            return "Something went wrong. Please try again."
        case .cancelled: return ""
        }
    }
}
