import Foundation
import Observation

/// Signatures CRUD + the org's default auto-add signature, mirrors web's
/// `apps/frontend/src/components/settings/signatures.component.tsx` (`GET/POST/PUT/DELETE
/// /signatures`) plus the dedicated `GET /signatures/default` the composer reads to decide
/// whether to auto-append a signature to new post content.
@MainActor
@Observable
public final class SignaturesViewModel {
    public private(set) var signatures: [SignatureDTO] = []
    public private(set) var defaultSignature: SignatureDTO?
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
            async let listTask = api.signatures()
            async let defaultTask = api.defaultSignature()
            let (list, def) = try await (listTask, defaultTask)
            signatures = list
            defaultSignature = def.id != nil ? def : nil
        } catch let error as SocialsAPIError {
            errorMessage = Self.message(for: error)
        } catch {
            errorMessage = "Something went wrong. Please try again."
        }
    }

    /// Content to auto-insert into a new post draft, mirrors web treating a signature with
    /// `autoAdd: true` as the one that gets appended automatically rather than requiring the
    /// user to tap "Use Signature".
    public var autoInsertContent: String? {
        guard let defaultSignature, defaultSignature.autoAdd == true,
            let content = defaultSignature.content, !content.isEmpty
        else { return nil }
        return content
    }

    // MARK: - CRUD

    @discardableResult
    public func createSignature(content: String, autoAdd: Bool) async -> Bool {
        await withReload {
            _ = try await self.api.createSignature(
                SignatureRequest(content: content, autoAdd: autoAdd))
        }
    }

    @discardableResult
    public func updateSignature(_ signature: SignatureDTO, content: String, autoAdd: Bool) async
        -> Bool
    {
        guard let id = signature.id else { return false }
        return await withReload {
            _ = try await self.api.updateSignature(
                id, body: SignatureRequest(content: content, autoAdd: autoAdd))
        }
    }

    @discardableResult
    public func deleteSignature(_ signature: SignatureDTO) async -> Bool {
        guard let id = signature.id else { return false }
        return await withReload {
            _ = try await self.api.deleteSignature(id)
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
        case .notFound: return "That signature couldn't be found."
        case .cancelled: return ""
        default: return "Something went wrong. Please try again."
        }
    }
}
