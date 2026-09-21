import CuantoNet
import Foundation

/// Tags, signatures, and media-library builders — split from `SocialsEndpoints` to keep that
/// file to the auth/account/post/push/AI surface. Same conventions: path-prefixed `basePath`,
/// `withOrg` for the `showorg` header (docs/MOBILE-API.md § Base URL & auth — org selection).
extension SocialsEndpoints {
    /// Local copy of `SocialsEndpoints.rawDecode` (file-`private` there, so not visible from
    /// this extension file) — same decode strategy for the media mutation endpoints whose
    /// response shape isn't pinned down by docs/MOBILE-API.md.
    private static let rawDecode: @Sendable (Data, JSONDecoder) throws -> OpaqueJSONResult = {
        data, _ in
        OpaqueJSONResult(raw: String(decoding: data, as: UTF8.self))
    }

    // MARK: - Tags (mobile-tags.controller.ts)

    public static func tags(orgId: String? = nil) -> Endpoint<TagsListResponse> {
        withOrg(Endpoint(path: "\(basePath)/tags"), orgId)
    }

    public static func createTag(
        _ body: CreateTagRequest, orgId: String? = nil
    ) throws -> Endpoint<TagDTO> {
        let endpoint = try Endpoint<TagDTO>(
            method: .post, path: "\(basePath)/tags", body: .json(body))
        return withOrg(endpoint, orgId)
    }

    public static func updateTag(
        _ id: String, body: CreateTagRequest, orgId: String? = nil
    ) throws -> Endpoint<TagDTO> {
        let endpoint = try Endpoint<TagDTO>(
            method: .put, path: "\(basePath)/tags/\(id)", body: .json(body))
        return withOrg(endpoint, orgId)
    }

    public static func deleteTag(_ id: String, orgId: String? = nil) -> Endpoint<TagDTO> {
        withOrg(Endpoint(method: .delete, path: "\(basePath)/tags/\(id)"), orgId)
    }

    // MARK: - Signatures (mobile-signatures.controller.ts)

    public static func signatures(orgId: String? = nil) -> Endpoint<[SignatureDTO]> {
        withOrg(Endpoint(path: "\(basePath)/signatures"), orgId)
    }

    public static func defaultSignature(orgId: String? = nil) -> Endpoint<SignatureDTO> {
        withOrg(Endpoint(path: "\(basePath)/signatures/default"), orgId)
    }

    public static func createSignature(
        _ body: SignatureRequest, orgId: String? = nil
    ) throws -> Endpoint<SignatureDTO> {
        let endpoint = try Endpoint<SignatureDTO>(
            method: .post, path: "\(basePath)/signatures", body: .json(body))
        return withOrg(endpoint, orgId)
    }

    public static func updateSignature(
        _ id: String, body: SignatureRequest, orgId: String? = nil
    ) throws -> Endpoint<SignatureDTO> {
        let endpoint = try Endpoint<SignatureDTO>(
            method: .put, path: "\(basePath)/signatures/\(id)", body: .json(body))
        return withOrg(endpoint, orgId)
    }

    public static func deleteSignature(
        _ id: String, orgId: String? = nil
    ) -> Endpoint<SignatureDTO> {
        withOrg(Endpoint(method: .delete, path: "\(basePath)/signatures/\(id)"), orgId)
    }

    // MARK: - Media library (mobile-media.controller.ts)

    public static func mediaList(
        page: Int? = nil, orgId: String? = nil
    ) -> Endpoint<MediaListResponse> {
        var endpoint = Endpoint<MediaListResponse>(path: "\(basePath)/media")
        if let page {
            endpoint = endpoint.query("page", String(page))
        }
        return withOrg(endpoint, orgId)
    }

    public static func deleteMedia(_ id: String, orgId: String? = nil) -> Endpoint<OpaqueJSONResult> {
        withOrg(
            Endpoint(method: .delete, path: "\(basePath)/media/\(id)", decode: rawDecode), orgId)
    }

    public static func saveMediaInformation(
        _ body: MediaInformationRequest, orgId: String? = nil
    ) throws -> Endpoint<OpaqueJSONResult> {
        let endpoint = try Endpoint<OpaqueJSONResult>(
            method: .post, path: "\(basePath)/media/information", body: .json(body),
            decode: rawDecode)
        return withOrg(endpoint, orgId)
    }

    public static func createMediaUpload(
        _ body: MediaCreateUploadRequest, orgId: String? = nil
    ) throws -> Endpoint<MediaCreateUploadResponse> {
        let endpoint = try Endpoint<MediaCreateUploadResponse>(
            method: .post, path: "\(basePath)/media/uploads", body: .json(body))
        return withOrg(endpoint, orgId)
    }

    public static func completeMediaUpload(
        _ body: MediaCompleteUploadRequest, orgId: String? = nil
    ) throws -> Endpoint<MediaCompleteUploadResponse> {
        let endpoint = try Endpoint<MediaCompleteUploadResponse>(
            method: .post, path: "\(basePath)/media/uploads/complete", body: .json(body))
        return withOrg(endpoint, orgId)
    }
}
