import SwiftUI

/// Lists the bundled open-source / third-party license notices from `OpenSourceNotices.all`.
/// Dynamic-Type friendly: license text wraps in a `Text` with no fixed height, and the source
/// link (where one exists) is an accessible `Link` row.
struct OpenSourceNoticesView: View {
    var body: some View {
        List(OpenSourceNotices.all) { notice in
            Section(notice.name) {
                Text(notice.license)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("\(notice.name) license: \(notice.license)")

                Text(notice.text)
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)

                if let url = notice.url {
                    Link("View source", destination: url)
                        .accessibilityLabel("\(notice.name) source link")
                }
            }
        }
        .navigationTitle("Open Source Notices")
    }
}
