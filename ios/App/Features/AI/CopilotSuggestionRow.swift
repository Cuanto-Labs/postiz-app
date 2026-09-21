import SwiftUI

/// One AI-generated suggestion in the copilot sheet: the rewritten/fitted text plus a "Use
/// this" action. `matchedGeometryEffect` ties the tapped row to its destination in the caller's
/// text field so applying a suggestion reads as a single continuous motion rather than a swap
/// (VISION decision 9 — AI motion must be polished).
struct CopilotSuggestionRow: View {
    let text: String
    var namespace: Namespace.ID?
    var onUse: () -> Void = {}

    @State private var didUse = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .if(namespace != nil) { view in
                    view.matchedGeometryEffect(id: text, in: namespace!)
                }

            Button("Use this") {
                didUse.toggle()
                onUse()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .sensoryFeedback(.selection, trigger: didUse)
            .accessibilityLabel("Use this suggestion")
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Suggestion: \(text)")
    }
}

extension View {
    @ViewBuilder
    fileprivate func `if`<Content: View>(
        _ condition: Bool, transform: (Self) -> Content
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
