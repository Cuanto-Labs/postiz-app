import Foundation
import Observation

/// The org's media library: paged listing, delete, and alt-text/thumbnail edits, mirrors web's
/// media library (`GET/DELETE /media`, `POST /media/information`) via the mobile-scoped
/// `/mobile/v1/media*` endpoints (docs/MOBILE-API.md § Media upload — 18 per page).
@MainActor
@Observable
public final class MediaLibraryViewModel {
    public private(set) var media: [MediaDTO] = []
    public private(set) var page = 1
    public private(set) var totalPages = 1
    public private(set) var isLoading = false
    public private(set) var isSaving = false
    public private(set) var errorMessage: String?

    private let api: any SocialsAPI

    public init(api: any SocialsAPI) {
        self.api = api
    }

    public var hasNextPage: Bool { page < totalPages }

    public func load(page: Int = 1) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let response = try await api.mediaList(page: page)
            if page == 1 {
                media = response.results
            } else {
                media.append(contentsOf: response.results)
            }
            self.page = page
            totalPages = response.pages
        } catch let error as SocialsAPIError {
            errorMessage = Self.message(for: error)
        } catch {
            errorMessage = "Something went wrong. Please try again."
        }
    }

    public func loadNextPageIfNeeded() async {
        guard hasNextPage, !isLoading else { return }
        await load(page: page + 1)
    }

    @discardableResult
    public func deleteMedia(_ item: MediaDTO) async -> Bool {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            _ = try await api.deleteMedia(item.id)
            media.removeAll { $0.id == item.id }
            return true
        } catch let error as SocialsAPIError {
            errorMessage = Self.message(for: error)
            return false
        } catch {
            errorMessage = "Something went wrong. Please try again."
            return false
        }
    }

    @discardableResult
    public func updateAlt(_ item: MediaDTO, alt: String) async -> Bool {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            _ = try await api.saveMediaInformation(
                MediaInformationRequest(
                    id: item.id, alt: alt, thumbnail: item.thumbnail,
                    thumbnailTimestamp: item.thumbnailTimestamp))
            if let index = media.firstIndex(where: { $0.id == item.id }) {
                media[index] = MediaDTO(
                    id: item.id, name: item.name, originalName: item.originalName,
                    path: item.path, thumbnail: item.thumbnail, alt: alt,
                    thumbnailTimestamp: item.thumbnailTimestamp, status: item.status,
                    processingError: item.processingError)
            }
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
        case .notFound: return "That file couldn't be found."
        case .cancelled: return ""
        default: return "Something went wrong. Please try again."
        }
    }
}
