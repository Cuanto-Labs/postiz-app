import Foundation

/// One bundled third-party (or shared first-party) component's license notice, shown in
/// `OpenSourceNoticesView`. Static — these don't change at runtime, so no API round trip.
struct OpenSourceNotice: Identifiable {
    let id = UUID()
    let name: String
    let license: String
    let url: URL?
    let text: String
}

/// Real license notices for everything this app is built on: Postiz itself (this app is an iOS
/// client for a fork of Postiz, AGPL-3.0, with a link back to the fork's source per the AGPL's
/// network-use source-availability requirement), the shared `CuantoKit` Swift package, and a
/// blanket Apple-frameworks note (SwiftUI, Foundation, etc. ship with the OS and carry no
/// separate bundled license text).
enum OpenSourceNotices {
    static let all: [OpenSourceNotice] = [
        OpenSourceNotice(
            name: "Postiz",
            license: "AGPL-3.0",
            url: URL(string: "https://github.com/Cuanto-Labs/cuanto-socials"),
            text: """
                This app is an iOS client for Cuanto Socials, a fork of Postiz \
                (https://github.com/gitroomhq/postiz-app), licensed under the GNU Affero \
                General Public License v3.0 (AGPL-3.0). The AGPL requires that anyone who runs a \
                modified version of this software as a network service make the complete \
                corresponding source code available to users of that service. The full source \
                for this fork, including any modifications, is available at the link above.
                """
        ),
        OpenSourceNotice(
            name: "CuantoKit",
            license: "Proprietary — Cuanto Labs",
            url: nil,
            text: """
                CuantoKit is a shared Swift package maintained by Cuanto Labs providing common \
                networking, Keychain, and UI utilities used across Cuanto Labs iOS apps, \
                including this one.
                """
        ),
        OpenSourceNotice(
            name: "Apple system frameworks",
            license: "Apple SLA",
            url: URL(string: "https://www.apple.com/legal/sla/"),
            text: """
                This app uses SwiftUI, Foundation, Observation, and other frameworks provided by \
                Apple as part of iOS. These frameworks are not bundled with the app and are \
                governed by the license terms of the operating system on which the app runs.
                """
        ),
    ]
}
