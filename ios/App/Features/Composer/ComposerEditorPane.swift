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
                    .frame(minHeight: 140)
                    .accessibilityLabel(accessibilityLabel)
            }
            CharacterCounterView(count: charCount, limit: charLimit)
        }
    }
}
