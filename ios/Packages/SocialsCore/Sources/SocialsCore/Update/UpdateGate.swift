/// Forced-update decision derived from the server's `/config.minVersion` and the installed
/// app version. Fails open: unparsable or nil `minVersion` never blocks the app.
public enum UpdateGate {
    public enum Decision: Sendable, Equatable {
        case ok
        case updateRequired(minimum: AppVersion)
    }

    public static func evaluate(minVersion: String?, installed: AppVersion) -> Decision {
        guard let minVersion, let minimum = AppVersion(minVersion) else {
            return .ok
        }

        if installed < minimum {
            return .updateRequired(minimum: minimum)
        }
        return .ok
    }
}
