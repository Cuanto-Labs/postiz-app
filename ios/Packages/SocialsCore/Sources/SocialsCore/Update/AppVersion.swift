import Foundation

/// Semantic-ish version: `MAJOR.MINOR.PATCH`. Missing trailing components default to 0.
/// Tolerates a leading `v` and a build suffix after `+` or `-` (e.g. `v1.2.3-beta`, `1.2.3+42`).
public struct AppVersion: Sendable, Comparable, LosslessStringConvertible {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public init(major: Int, minor: Int = 0, patch: Int = 0) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public init?(_ description: String) {
        var raw = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }

        if raw.hasPrefix("v") || raw.hasPrefix("V") {
            raw.removeFirst()
        }

        // Strip build/prerelease suffix after '+' or '-'.
        if let cut = raw.firstIndex(where: { $0 == "+" || $0 == "-" }) {
            raw = String(raw[raw.startIndex..<cut])
        }

        guard !raw.isEmpty else { return nil }

        let parts = raw.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 3, !parts.isEmpty else { return nil }

        var numbers: [Int] = []
        for part in parts {
            guard let value = Int(part), value >= 0 else { return nil }
            numbers.append(value)
        }

        self.major = numbers[0]
        self.minor = numbers.count > 1 ? numbers[1] : 0
        self.patch = numbers.count > 2 ? numbers[2] : 0
    }

    public var description: String {
        "\(major).\(minor).\(patch)"
    }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }

    /// Installed version read from `CFBundleShortVersionString`, falling back to `0.0.0`.
    public static func installed(bundle: Bundle) -> AppVersion {
        guard
            let raw = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            let parsed = AppVersion(raw)
        else {
            return AppVersion(major: 0, minor: 0, patch: 0)
        }
        return parsed
    }
}
