import SocialsCore
import SwiftUI

/// Read-only webhook rows (name, url, connected channels). Mirrors web's `webhooks.tsx` list —
/// no create/edit here (VISION §7 scope). A footer states this is a fact, not a placeholder.
struct WebhooksListView: View {
    let webhooks: [MobileWebhook]

    var body: some View {
        if webhooks.isEmpty {
            Text("No webhooks configured")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            ForEach(webhooks, id: \.id) { webhook in
                row(webhook)
            }
            Text("Manage webhooks on the web")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func row(_ webhook: MobileWebhook) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(webhook.name)
                .font(.body)
            Text(webhook.url)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if !webhook.integrations.isEmpty {
                Text(webhook.integrations.map(\.integration.name).joined(separator: ", "))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
