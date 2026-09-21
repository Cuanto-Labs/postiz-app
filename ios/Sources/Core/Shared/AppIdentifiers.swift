import Foundation

public enum AppIdentifiers {
    public static let bundleBase = "com.cuantolabs.socials"
    public static let appGroup = "group.com.cuantolabs.socials"
    public static let keychainAccessGroup = "8AWCD3T4B5.com.cuantolabs.socials.shared"
    public static let urlScheme = "cuantosocials"
    public static let universalLinkHost = "socials.cuantolabs.com"
}

public enum BuildConfig {
    public static var apiBaseURL: URL {
        if let value = Bundle.main.object(forInfoDictionaryKey: "SocialsAPIBaseURL") as? String,
           let url = URL(string: value) {
            return url
        }
        return URL(string: "https://api.socials.cuantolabs.com")!
    }
}
