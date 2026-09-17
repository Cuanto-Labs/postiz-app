import Foundation
import Testing

@testable import SocialsCore

@Suite("LiveActionExecutor")
struct LiveActionExecutorTests {

    private func postGroupDTO(group: String = "g1") -> PostGroupDTO {
        PostGroupDTO(
            id: group, group: group, publishDate: nil, status: nil,
            integration: PostIntegrationRef(id: "chan-1", name: "Chan", picture: nil, providerIdentifier: nil),
            content: .string("hello")
        )
    }

    private func createBody() -> CreatePostBody {
        CreatePostBody(type: "now", posts: [postGroupDTO()])
    }

    private func action(
        kind: PendingActionKind, payload: some Encodable, idempotencyKey: String = IdempotencyKey().value
    ) -> PendingActionSnapshot {
        PendingActionSnapshot(
            id: UUID(), orgId: "org-1", kind: kind,
            payload: try! JSONEncoder().encode(payload), idempotencyKey: idempotencyKey,
            createdAt: .now, attempts: 0, nextAttemptAt: .now, lastError: nil, status: .pending
        )
    }

    @Test("createPost decodes the payload and calls SocialsAPI.createPost with the reconstructed key")
    func createPostSucceeds() async throws {
        let api = StubSocialsAPI()
        await api.setCreatePostResults([.success(postGroupDTO())])
        let executor = LiveActionExecutor(api: api)
        let key = IdempotencyKey().value

        try await executor.execute(action(kind: .createPost, payload: createBody(), idempotencyKey: key))

        let calls = await api.createPostCalls
        #expect(calls.count == 1)
        #expect(calls[0].key?.value == key)
    }

    @Test("updatePost decodes group + body and calls SocialsAPI.updatePost")
    func updatePostSucceeds() async throws {
        let api = StubSocialsAPI()
        await api.setUpdatePostResults([.success(postGroupDTO())])
        let executor = LiveActionExecutor(api: api)
        let payload = UpdatePostPayload(group: "g1", body: createBody())

        try await executor.execute(action(kind: .updatePost, payload: payload))

        let calls = await api.updatePostCalls
        #expect(calls.count == 1)
        #expect(calls[0].group == "g1")
    }

    @Test("reschedulePost decodes group/date/action and calls SocialsAPI.reschedule")
    func reschedulePostSucceeds() async throws {
        let api = StubSocialsAPI()
        await api.setRescheduleResults([
            .success(RescheduleResponse(group: "g1", date: "2026-01-01T00:00:00Z"))
        ])
        let executor = LiveActionExecutor(api: api)
        let payload = ReschedulePostPayload(group: "g1", date: "2026-01-01T00:00:00Z", action: nil)

        try await executor.execute(action(kind: .reschedulePost, payload: payload))

        let calls = await api.rescheduleCalls
        #expect(calls.count == 1)
        #expect(calls[0].group == "g1")
    }

    @Test("deletePost decodes group and calls SocialsAPI.deletePost")
    func deletePostSucceeds() async throws {
        let api = StubSocialsAPI()
        await api.setDeletePostResults([.success(OkResponse(ok: true))])
        let executor = LiveActionExecutor(api: api)

        try await executor.execute(action(kind: .deletePost, payload: DeletePostPayload(group: "g1")))

        let calls = await api.deletePostCalls
        #expect(calls == ["g1"])
    }

    @Test("upsertPushDevice decodes the body and calls SocialsAPI.upsertPushDevice")
    func upsertPushDeviceSucceeds() async throws {
        let api = StubSocialsAPI()
        let device = PushDeviceUpsert(
            apnsToken: "token", environment: "sandbox", bundleId: nil, locale: nil, timezone: nil,
            prefs: nil)
        await api.setUpsertPushDeviceResults([.success(PushDeviceResponse(device: device))])
        let executor = LiveActionExecutor(api: api)

        try await executor.execute(action(kind: .upsertPushDevice, payload: device))

        let calls = await api.upsertPushDeviceCalls
        #expect(calls == [device])
    }

    @Test("offline maps to SyncError.retryable")
    func offlineIsRetryable() async throws {
        let api = StubSocialsAPI()
        await api.setCreatePostResults([.failure(SocialsAPIError.offline)])
        let executor = LiveActionExecutor(api: api)

        do {
            try await executor.execute(action(kind: .createPost, payload: createBody()))
            Issue.record("expected throw")
        } catch let error as SyncError {
            guard case .retryable = error else {
                Issue.record("expected .retryable, got \(error)")
                return
            }
        } catch {
            Issue.record("expected SyncError, got \(error)")
        }
    }

    @Test("idempotencyConflict maps to SyncError.permanent")
    func idempotencyConflictIsPermanent() async throws {
        let api = StubSocialsAPI()
        await api.setCreatePostResults([.failure(SocialsAPIError.idempotencyConflict)])
        let executor = LiveActionExecutor(api: api)

        do {
            try await executor.execute(action(kind: .createPost, payload: createBody()))
            Issue.record("expected throw")
        } catch let error as SyncError {
            guard case .permanent = error else {
                Issue.record("expected .permanent, got \(error)")
                return
            }
        } catch {
            Issue.record("expected SyncError, got \(error)")
        }
    }

    @Test("unauthorized maps to SyncError.permanent")
    func unauthorizedIsPermanent() async throws {
        let api = StubSocialsAPI()
        await api.setDeletePostResults([.failure(SocialsAPIError.unauthorized)])
        let executor = LiveActionExecutor(api: api)

        do {
            try await executor.execute(action(kind: .deletePost, payload: DeletePostPayload(group: "g1")))
            Issue.record("expected throw")
        } catch let error as SyncError {
            guard case .permanent = error else {
                Issue.record("expected .permanent, got \(error)")
                return
            }
        } catch {
            Issue.record("expected SyncError, got \(error)")
        }
    }

    @Test("server(5xx) maps to SyncError.retryable")
    func serverErrorIsRetryable() async throws {
        let api = StubSocialsAPI()
        await api.setRescheduleResults([.failure(SocialsAPIError.server(code: 503, message: nil))])
        let executor = LiveActionExecutor(api: api)
        let payload = ReschedulePostPayload(group: "g1", date: "2026-01-01T00:00:00Z", action: nil)

        do {
            try await executor.execute(action(kind: .reschedulePost, payload: payload))
            Issue.record("expected throw")
        } catch let error as SyncError {
            guard case .retryable = error else {
                Issue.record("expected .retryable, got \(error)")
                return
            }
        } catch {
            Issue.record("expected SyncError, got \(error)")
        }
    }
}

extension StubSocialsAPI {
    fileprivate func setCreatePostResults(_ results: [Result<PostGroupDTO, Error>]) {
        createPostResults = results
    }

    fileprivate func setUpdatePostResults(_ results: [Result<PostGroupDTO, Error>]) {
        updatePostResults = results
    }

    fileprivate func setRescheduleResults(_ results: [Result<RescheduleResponse, Error>]) {
        rescheduleResults = results
    }

    fileprivate func setDeletePostResults(_ results: [Result<OkResponse, Error>]) {
        deletePostResults = results
    }

    fileprivate func setUpsertPushDeviceResults(_ results: [Result<PushDeviceResponse, Error>]) {
        upsertPushDeviceResults = results
    }
}
