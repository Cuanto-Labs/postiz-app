import SwiftUI

/// Icon + title row for a settings-hub link, used as the `label` of a `NavigationLink`. Matches
/// the system Settings app convention: leading SF Symbol, plain title, chevron supplied by the
/// enclosing `NavigationLink`.
struct SettingsRow: View {
    let icon: String
    let title: String

    var body: some View {
        Label(title, systemImage: icon)
            .accessibilityLabel(title)
    }
}
