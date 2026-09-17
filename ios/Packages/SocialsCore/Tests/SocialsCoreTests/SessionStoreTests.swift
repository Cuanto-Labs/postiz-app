import CuantoCore
import CuantoNet
import CuantoTesting
import Foundation
import Testing

@testable import SocialsCore

@Suite("SessionStore")
struct SessionStoreTests {

    private func authResponse(orgId: String = "org-1") -> MobileAuthResponse {
        MobileAuthResponse(
            accessToken: "access-1", refreshToken: "refresh-1", expiresIn: 3600,
            sessionId: "session-1",
            user: MobileUser(id: "u1", email: "a@b.com", name: "A", lastName: nil, pictureId: nil),
            orgs: [MobileOrg(id: orgId, name: "Org", role: "owner", disabled: false)])
    }

    private func makeStore(
        keychain: KeychainStore,
        refresh: @escaping @Sendable (_ refreshToken: String) async throws -> MobileTokens
    ) async -> SessionStore {
        await SessionStore(keychain: keychain, refresh: refresh)
    }

    @Test("signIn persists the session and token() returns the access token")
    func signInPersistsAndTokenReturns() async throws {
        let keychain = KeychainStore.ephemeral()
        let store = await makeStore(keychain: keychain) { _ in
            MobileTokens(accessToken: "unused", refreshToken: "unused", expiresIn: 1, sessionId: "s")
        }

        try await store.signIn(authResponse())

        #expect(await store.token() == "access-1")
        if case .signedIn(let user, let orgs, let orgId) = await store.state {
            #expect(user.id == "u1")
            #expect(orgs.count == 1)
            #expect(orgId == "org-1")
        } else {
            Issue.record("expected .signedIn after signIn")
        }
    }

    @Test(
        "20 concurrent refresh() calls invoke the refresh closure exactly once and all receive the new token"
    )
    func refreshIsSingleFlight() async throws {
        let keychain = KeychainStore.ephemeral()
        let counter = CallCounter()
        let store = await makeStore(keychain: keychain) { refreshToken in
            await counter.increment()
            return MobileTokens(
                accessToken: "fresh-\(refreshToken)", refreshToken: "refresh-2", expiresIn: 3600,
                sessionId: "s")
        }
        try await store.signIn(authResponse())

        let results = try await withThrowingTaskGroup(of: String?.self) { group in
            for _ in 0..<20 {
                group.addTask { try await store.refresh() }
            }
            var collected: [String?] = []
            for try await value in group { collected.append(value) }
            return collected
        }

        #expect(await counter.count == 1)
        #expect(results.count == 20)
        #expect(results.allSatisfy { $0 == "fresh-refresh-1" })
        #expect(await store.token() == "fresh-refresh-1")
    }

    @Test("a 401 on refresh signs out, clears the keychain, and emits .signedOut")
    func refresh401SignsOut() async throws {
        let keychain = KeychainStore.ephemeral()
        let store = await makeStore(keychain: keychain) { _ in
            throw APIError.unauthorized
        }
        try await store.signIn(authResponse())

        let result = try await store.refresh()

        #expect(result == nil)
        #expect(await store.state == .signedOut)

        var iterator = await store.events.makeAsyncIterator()
        let event = await iterator.next()
        #expect(event == .signedOut)

        // Keychain item was deleted — a fresh SessionStore over the same keychain sees signedOut.
        let restored = await makeStore(keychain: keychain) { _ in
            MobileTokens(accessToken: "n", refreshToken: "n", expiresIn: 1, sessionId: "s")
        }
        #expect(await restored.state == .signedOut)
    }

    @Test("an offline error during refresh() rethrows and leaves the session signed in with the old token")
    func refreshOfflineRethrowsAndKeepsSession() async throws {
        let keychain = KeychainStore.ephemeral()
        let store = await makeStore(keychain: keychain) { _ in
            throw APIError.offline
        }
        try await store.signIn(authResponse())

        do {
            _ = try await store.refresh()
            Issue.record("expected .offline to rethrow")
        } catch let error as APIError {
            #expect(error == .offline)
        }

        #expect(await store.token() == "access-1")
        if case .signedIn = await store.state {
        } else {
            Issue.record("expected still .signedIn after an offline refresh failure")
        }
    }

    @Test("a new SessionStore over the same keychain restores the session (cold start)")
    func restoresFromKeychainOnColdStart() async throws {
        let keychain = KeychainStore.ephemeral()
        let first = await makeStore(keychain: keychain) { _ in
            MobileTokens(accessToken: "unused", refreshToken: "unused", expiresIn: 1, sessionId: "s")
        }
        try await first.signIn(authResponse())

        let second = await makeStore(keychain: keychain) { _ in
            MobileTokens(accessToken: "unused", refreshToken: "unused", expiresIn: 1, sessionId: "s")
        }

        #expect(await second.token() == "access-1")
        if case .signedIn(let user, let orgs, let orgId) = await second.state {
            #expect(user.id == "u1")
            #expect(orgs.count == 1)
            #expect(orgId == "org-1")
        } else {
            Issue.record("expected .signedIn after cold-start restore")
        }
    }
}

/// Thread-safe call counter for asserting single-flight refresh behavior.
private actor CallCounter {
    private(set) var count = 0

    func increment() {
        count += 1
    }
}
