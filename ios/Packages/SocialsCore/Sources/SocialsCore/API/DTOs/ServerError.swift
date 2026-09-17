import Foundation

/// Parses the mobile API's error body, which comes in two shapes (docs/MOBILE-API.md):
/// `{ msg: "<message>" }` from `MobileAuthMiddleware`, or Nest's default
/// `{ statusCode, message, error }` from unhandled auth-route exceptions, where `message`
/// may be a single string or an array of validation messages.
public enum ServerErrorMessage {
    private struct MsgBody: Decodable {
        let msg: String
    }

    private struct NestBody: Decodable {
        let statusCode: Int?
        let message: StringOrArray?
        let error: String?
    }

    private enum StringOrArray: Decodable {
        case string(String)
        case array([String])

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let value = try? container.decode(String.self) {
                self = .string(value)
                return
            }
            self = .array(try container.decode([String].self))
        }

        var firstMessage: String? {
            switch self {
            case .string(let value): value
            case .array(let values): values.first
            }
        }
    }

    /// Best-effort extraction of a human-readable message from an error response body.
    /// Returns `nil` if `data` doesn't match either known shape.
    public static func parse(_ data: Data) -> String? {
        let decoder = JSONDecoder()

        if let msgBody = try? decoder.decode(MsgBody.self, from: data) {
            return msgBody.msg
        }

        if let nestBody = try? decoder.decode(NestBody.self, from: data) {
            return nestBody.message?.firstMessage ?? nestBody.error
        }

        return nil
    }
}
