import Foundation
import Testing

@testable import SocialsCore

@Suite("PostDetailViewModel")
@MainActor
struct PostDetailViewModelTests {

    private func postDTO(status: String) -> PostGroupDTO {
        PostGroupDTO(
            id: "post-1", group: "post-1", publishDate: "2024-09-10T12:00:00Z", status: status,
            integration: PostIntegrationRef(id: "chan-1", name: nil, picture: nil, providerIdentifier: nil),
            content: .string("hello")
        )
    }

    @Test("load fetches the post and builds its status timeline")
    func loadFetchesPostAndTimeline() async throws {
        let api = StubSocialsAPI()
        await api.setPostResults([.success(postDTO(status: "PUBLISHED"))])
        let viewModel = PostDetailViewModel(postId: "post-1", api: api)

        await viewModel.load()

        #expect(viewModel.post?.id == "post-1")
        #expect(viewModel.statusTimeline?.current == .published)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("retry no-ops when the post is not failed")
    func retryNoOpsWhenNotFailed() async throws {
        let api = StubSocialsAPI()
        await api.setPostResults([.success(postDTO(status: "QUEUE"))])
        let viewModel = PostDetailViewModel(postId: "post-1", api: api)
        await viewModel.load()

        await viewModel.retry()

        #expect(await api.rescheduleCalls.isEmpty)
    }

    @Test("retry reschedules a failed post and reloads it")
    func retryReschedulesFailedPost() async throws {
        let api = StubSocialsAPI()
        await api.setPostResults([
            .success(postDTO(status: "ERROR")),
            .success(postDTO(status: "QUEUE")),
        ])
        await api.setRescheduleResults([.success(RescheduleResponse(group: "post-1", date: "2024-09-10T12:00:00Z"))])
        let viewModel = PostDetailViewModel(postId: "post-1", api: api)
        await viewModel.load()
        #expect(viewModel.statusTimeline?.isFailed == true)

        await viewModel.retry()

        #expect(await api.rescheduleCalls.count == 1)
        #expect(viewModel.statusTimeline?.current == .queued)
        #expect(!viewModel.isRetrying)
    }

    @Test("loadPreview fetches the recursive preview posts")
    func loadPreviewFetches() async throws {
        let api = StubSocialsAPI()
        await api.setPreviewResults([.success(PostPreviewResponse(posts: [postDTO(status: "PUBLISHED")]))])
        let viewModel = PostDetailViewModel(postId: "post-1", api: api)

        await viewModel.loadPreview()

        #expect(viewModel.previewPosts.map(\.id) == ["post-1"])
        #expect(viewModel.errorMessage == nil)
    }

    @Test("loadComments fetches and addComment prepends locally")
    func commentsLoadAndAdd() async throws {
        let api = StubSocialsAPI()
        await api.setCommentsResults([
            .success(
                PostCommentsResponse(comments: [
                    PostCommentDTO(id: "c1", content: "first", postId: "post-1", userId: "u1", createdAt: nil)
                ]))
        ])
        await api.setAddCommentResults([
            .success(PostCommentDTO(id: "c2", content: "second", postId: "post-1", userId: "u1", createdAt: nil))
        ])
        let viewModel = PostDetailViewModel(postId: "post-1", api: api)

        await viewModel.loadComments()
        await viewModel.addComment("second")

        #expect(viewModel.comments.map(\.id) == ["c2", "c1"])
    }

    @Test("loadStatistics fetches the opaque statistics payload")
    func loadStatisticsFetches() async throws {
        let api = StubSocialsAPI()
        await api.setStatisticsResults([.success(OpaqueJSONResult(raw: "{\"clicks\":[]}"))])
        let viewModel = PostDetailViewModel(postId: "post-1", api: api)

        await viewModel.loadStatistics()

        #expect(viewModel.statistics?.raw == "{\"clicks\":[]}")
        #expect(viewModel.errorMessage == nil)
    }

    @Test("load surfaces a message on failure")
    func loadSurfacesError() async throws {
        let api = StubSocialsAPI()
        await api.setPostResults([.failure(SocialsAPIError.offline)])
        let viewModel = PostDetailViewModel(postId: "post-1", api: api)

        await viewModel.load()

        #expect(viewModel.post == nil)
        #expect(viewModel.errorMessage != nil)
    }
}

extension StubSocialsAPI {
    fileprivate func setPostResults(_ results: [Result<PostGroupDTO, Error>]) {
        postResults = results
    }
    fileprivate func setRescheduleResults(_ results: [Result<RescheduleResponse, Error>]) {
        rescheduleResults = results
    }
    fileprivate func setPreviewResults(_ results: [Result<PostPreviewResponse, Error>]) {
        previewResults = results
    }
    fileprivate func setCommentsResults(_ results: [Result<PostCommentsResponse, Error>]) {
        commentsResults = results
    }
    fileprivate func setAddCommentResults(_ results: [Result<PostCommentDTO, Error>]) {
        addCommentResults = results
    }
    fileprivate func setStatisticsResults(_ results: [Result<OpaqueJSONResult, Error>]) {
        statisticsResults = results
    }
}
