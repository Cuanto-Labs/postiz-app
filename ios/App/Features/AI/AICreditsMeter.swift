import SwiftUI

/// "N credits left" meter for AI image generation, mirrors web's credits display in
/// `ai.image.tsx`. Shown across `.ready`/`.generating`/`.generated`, not just the initial load,
/// so `credits` is passed in directly rather than derived from `AIImageViewModel.phase`.
struct AICreditsMeter: View {
    let credits: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkles") // a11y-ok: labeled via .accessibilityElement(children: .combine) below
                .foregroundStyle(.secondary)
            Text("\(credits) credit\(credits == 1 ? "" : "s") left")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(credits) AI image credit\(credits == 1 ? "" : "s") left")
    }
}
