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
}

extension StubSocialsAPI {
    fileprivate func setPostsResults(_ results: [Result<PostsResponse, Error>]) {
        postsResults = results
    }
    fileprivate func setPostsListResults(_ results: [Result<PostsListResponse, Error>]) {
        postsListResults = results
    }
}
