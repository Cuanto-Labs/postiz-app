import Foundation
import HTTPTypes

/// Client-generated idempotency key for `POST /mobile/v1/posts` and `PUT
/// /mobile/v1/posts/:group` (docs/MOBILE-API.md § Idempotency-Key): 8–128 chars, sent under
/// the `Idempotency-Key` header. Outside that range the server responds
/// `400 { msg: 'Invalid Idempotency-Key' }`.
public struct IdempotencyKey: Sendable, Equatable {
    /// Header name the key is sent under.
    public static let headerName = HTTPField.Name("Idempotency-Key")!

    public let value: String

    /// Generates a fresh key from a UUID (36 chars — well within the 8...128 range).
    public init() {
        self.value = UUID().uuidString
    }

    /// Validates `rawValue` is 8...128 chars; `nil` otherwise.
    public init?(rawValue: String) {
        guard (8...128).contains(rawValue.count) else { return nil }
        self.value = rawValue
    }
}
