import Foundation
import Testing

@testable import SocialsCore

@Suite("CalendarViewModel")
@MainActor
struct CalendarViewModelTests {

    private func makeCacheStore() throws -> CacheStore {
        let container = try SocialsSchema.makeContainer(inMemory: true)
        return CacheStore(modelContainer: container)
    }

    private func postDTO(group: String, date: Date) -> PostGroupDTO {
        PostGroupDTO(
            id: group, group: group, publishDate: ISO8601DateFormatter().string(from: date),
            status: "QUEUE",
            integration: PostIntegrationRef(id: "chan-1", name: nil, picture: nil, providerIdentifier: nil),
            content: .string("hello")
        )
    }

    private func listItemDTO(id: String) -> PostListItemDTO {
        PostListItemDTO(
            id: id, content: .string("hi"), publishDate: nil, releaseURL: nil, releaseId: nil,
            state: "QUEUE", group: id, integration: nil, intervalInDays: nil, creationMethod: nil
        )
    }

    @Test("refresh in week mode fetches the isoWeek window and upserts the cache")
    func refreshWeekModeFetchesAndCaches() async throws {
        let api = StubSocialsAPI()
        let cacheStore = try makeCacheStore()
        let referenceDate = Date(timeIntervalSince1970: 1_726_000_000)  // 2024-09-10 (a Tuesday)
        let post = postDTO(group: "g1", date: referenceDate)
        await api.setPostsResults([.success(PostsResponse(posts: [post]))])
        let viewModel = CalendarViewModel(
            api: api, cacheStore: cacheStore, orgId: "org-1", display: .week,
            referenceDate: referenceDate)

        await viewModel.refresh()

        #expect(viewModel.posts.map(\.id) == ["g1"])
        #expect(viewModel.errorMessage == nil)
        #expect(!viewModel.isLoading)
        #expect(await api.postsCalls.count == 1)
        let window = CalendarRange.week(containing: referenceDate)
        let cached = try await cacheStore.posts(orgId: "org-1", in: window)
        #expect(cached.map(\.id) == ["g1"])
    }

    @Test("switching to list mode fetches via postsList and computes total pages")
    func listModeFetchesPaginated() async throws {
        let api = StubSocialsAPI()
        let cacheStore = try makeCacheStore()
        await api.setPostsListResults([
            .success(
                PostsListResponse(
                    posts: [listItemDTO(id: "l1"), listItemDTO(id: "l2")], total: 150, page: 0,
                    limit: 100, hasMore: true))
        ])
        let viewModel = CalendarViewModel(api: api, cacheStore: cacheStore, orgId: "org-1")

        await viewModel.setDisplay(.list)

        #expect(viewModel.listPosts.map(\.id) == ["l1", "l2"])
        #expect(viewModel.listTotal == 150)
        #expect(viewModel.listTotalPages == 2)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("refresh surfaces a message on failure")
    func refreshSurfacesError() async throws {
        let api = StubSocialsAPI()
        let cacheStore = try makeCacheStore()
        await api.setPostsResults([.failure(SocialsAPIError.offline)])
        let viewModel = CalendarViewModel(api: api, cacheStore: cacheStore, orgId: "org-1")

        await viewModel.refresh()

        #expect(viewModel.posts.isEmpty)
        #expect(viewModel.errorMessage != nil)
    }

    @Test("cache read-through paints cached posts before the network responds")
    func cacheReadThroughPaintsBeforeNetwork() async throws {
        let api = StubSocialsAPI()
        let cacheStore = try makeCacheStore()
        let referenceDate = Date(timeIntervalSince1970: 1_726_000_000)
        let window = CalendarRange.week(containing: referenceDate)
        let cachedPost = postDTO(group: "cached-1", date: referenceDate)
        try await cacheStore.upsertPosts([cachedPost], orgId: "org-1", window: window)
        // Network returns a different set — read-through should show cache first, then replace.
        await api.setPostsResults([.success(PostsResponse(posts: [postDTO(group: "net-1", date: referenceDate)]))])
        let viewModel = CalendarViewModel(
            api: api, cacheStore: cacheStore, orgId: "org-1", display: .week,
            referenceDate: referenceDate)

        await viewModel.refresh()

        #expect(viewModel.posts.map(\.id) == ["net-1"])
    }

    @Test("reschedule moves the card immediately and confirms via the API")
    func rescheduleUpdatesOptimisticallyOnSuccess() async throws {
        let api = StubSocialsAPI()
        let cacheStore = try makeCacheStore()
        let referenceDate = Date(timeIntervalSince1970: 1_726_000_000)
        let post = postDTO(group: "g1", date: referenceDate)
        await api.setPostsResults([.success(PostsResponse(posts: [post]))])
        await api.setRescheduleResults([.success(RescheduleResponse(group: "g1", date: "2024-09-12T00:00:00Z"))])
        let viewModel = CalendarViewModel(
            api: api, cacheStore: cacheStore, orgId: "org-1", display: .week,
            referenceDate: referenceDate)
        await viewModel.refresh()
        let newDate = referenceDate.addingTimeInterval(86_400)

        let succeeded = await viewModel.reschedule(group: "g1", to: newDate)

        #expect(succeeded)
        #expect(viewModel.posts.first?.publishDate != post.publishDate)
        #expect(viewModel.errorMessage == nil)
        #expect(await api.rescheduleCalls.count == 1)
    }

    @Test("reschedule rolls back the local move when the API call fails")
    func rescheduleRollsBackOnFailure() async throws {
        let api = StubSocialsAPI()
        let cacheStore = try makeCacheStore()
        let referenceDate = Date(timeIntervalSince1970: 1_726_000_000)
        let post = postDTO(group: "g1", date: referenceDate)
        await api.setPostsResults([.success(PostsResponse(posts: [post]))])
        await api.setRescheduleResults([.failure(SocialsAPIError.offline)])
        let viewModel = CalendarViewModel(
            api: api, cacheStore: cacheStore, orgId: "org-1", display: .week,
            referenceDate: referenceDate)
        await viewModel.refresh()
        let newDate = referenceDate.addingTimeInterval(86_400)

        let succeeded = await viewModel.reschedule(group: "g1", to: newDate)

        #expect(!succeeded)
        #expect(viewModel.posts.first?.publishDate == post.publishDate)
        #expect(viewModel.errorMessage != nil)
    }

    @Test("duplicate creates a new post and appends it")
    func duplicateAppendsCreatedPost() async throws {
        let api = StubSocialsAPI()
        let cacheStore = try makeCacheStore()
        let referenceDate = Date(timeIntervalSince1970: 1_726_000_000)
        let post = postDTO(group: "g1", date: referenceDate)
        await api.setCreatePostResults([.success(postDTO(group: "g2", date: referenceDate))])
        let viewModel = CalendarViewModel(api: api, cacheStore: cacheStore, orgId: "org-1")

        await viewModel.duplicate(post)

        #expect(viewModel.posts.map(\.id) == ["g2"])
        #expect(viewModel.errorMessage == nil)
        #expect(await api.createPostCalls.count == 1)
    }

    @Test("delete removes the post from the grid on success")
    func deleteRemovesPostOnSuccess() async throws {
        let api = StubSocialsAPI()
        let cacheStore = try makeCacheStore()
        let referenceDate = Date(timeIntervalSince1970: 1_726_000_000)
        let post = postDTO(group: "g1", date: referenceDate)
        await api.setPostsResults([.success(PostsResponse(posts: [post]))])
        await api.setDeletePostResults([.success(OkResponse(ok: true))])
        let viewModel = CalendarViewModel(
            api: api, cacheStore: cacheStore, orgId: "org-1", display: .week,
            referenceDate: referenceDate)
        await viewModel.refresh()

        await viewModel.delete(group: "g1")

        #expect(viewModel.posts.isEmpty)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("loadPreview populates previewPosts on success")
    func loadPreviewPopulatesPosts() async throws {
        let api = StubSocialsAPI()
        let cacheStore = try makeCacheStore()
        let referenceDate = Date(timeIntervalSince1970: 1_726_000_000)
        let post = postDTO(group: "g1", date: referenceDate)
        await api.setPreviewResults([.success(PostPreviewResponse(posts: [post]))])
        let viewModel = CalendarViewModel(api: api, cacheStore: cacheStore, orgId: "org-1")

        await viewModel.loadPreview(group: "g1")

        #expect(viewModel.previewPosts.map(\.id) == ["g1"])
        #expect(!viewModel.isLoadingPreview)
        #expect(viewModel.errorMessage == nil)
    }
}

extension StubSocialsAPI {
    fileprivate func setPostsResults(_ results: [Result<PostsResponse, Error>]) {
        postsResults = results
    }
    fileprivate func setPostsListResults(_ results: [Result<PostsListResponse, Error>]) {
        postsListResults = results
    }
    fileprivate func setRescheduleResults(_ results: [Result<RescheduleResponse, Error>]) {
        rescheduleResults = results
    }
    fileprivate func setCreatePostResults(_ results: [Result<PostGroupDTO, Error>]) {
        createPostResults = results
    }
    fileprivate func setDeletePostResults(_ results: [Result<OkResponse, Error>]) {
        deletePostResults = results
    }
    fileprivate func setPreviewResults(_ results: [Result<PostPreviewResponse, Error>]) {
        previewResults = results
    }
}
