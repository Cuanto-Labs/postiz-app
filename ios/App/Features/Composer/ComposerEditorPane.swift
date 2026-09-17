import CuantoUI
import SocialsCore
import SwiftUI

/// Text editor + character counter, shared by the global editor and each per-channel customize
/// tab. Mirrors web's `editor.tsx` pairing a `TextEditor`-equivalent with a live counter driven
/// off the tightest selected channel's `maxLength`.
struct ComposerEditorPane: View {
    let content: Binding<String>
    let charCount: Int
    let charLimit: Int
    var placeholder: String = "What's on your mind?"
    var accessibilityLabel: String = "Post content"
    /// When set, shows an "AI copilot" trigger that presents `CopilotSheet`; its "Use" action
    /// forwards the picked suggestion to `ComposerViewModel.applySuggestion(_:mode:)`.
    var copilotViewModel: CopilotViewModel?
    var applySuggestion: ((String) -> Void)?

    @Environment(\.cuantoTheme) private var theme
    @State private var showCopilot = false

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            ZStack(alignment: .topLeading) {
                if content.wrappedValue.isEmpty {
                    Text(placeholder)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
                TextEditor(text: content)
                    // Without this the editor paints its own opaque background over the
                    // placeholder underneath it, so an empty composer showed a blank slab with no
                    // hint that it was a text field at all.
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 140)
                    .accessibilityLabel(accessibilityLabel)
                    .accessibilityIdentifier(accessibilityLabel)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.token(.card, in: theme))
            .clipShape(RoundedRectangle(cornerRadius: theme.radius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: theme.radius.sm)
                    .strokeBorder(Color.token(.border, in: theme), lineWidth: 1)
            )
            HStack {
                if let copilotViewModel, applySuggestion != nil {
                    Button {
                        showCopilot = true
                    } label: {
                        Label("AI copilot", systemImage: "sparkles")
                    }
                    .accessibilityLabel("Open AI copilot")
                    .sheet(isPresented: $showCopilot) {
                        CopilotSheet(
                            content: content.wrappedValue, viewModel: copilotViewModel,
                            onApply: { suggestion in applySuggestion?(suggestion) })
                    }
                }
                Spacer()
                CharacterCounterView(count: charCount, limit: charLimit)
            }
        }
    }
}
