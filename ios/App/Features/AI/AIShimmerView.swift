import SwiftUI

/// Shared shimmer skeleton for AI generation screens (VISION decision 9): a rounded placeholder
/// bar that sweeps a soft highlight left-to-right while content is loading. Under Reduce Motion
/// it renders as a plain static placeholder instead of animating, per the decision's cross-fade
/// fallback.
struct AIShimmerView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var height: CGFloat = 44
    var cornerRadius: CGFloat = 6

    @State private var phase: CGFloat = -1

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(.secondary.opacity(0.15))
            .frame(height: height)
            .overlay {
                if !reduceMotion {
                    GeometryReader { proxy in
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.4), .clear],
                            startPoint: .leading, endPoint: .trailing
                        )
                        .frame(width: proxy.size.width * 0.6)
                        .offset(x: phase * proxy.size.width)
                        .animation(
                            .linear(duration: 1.1).repeatForever(autoreverses: false),
                            value: phase
                        )
                    }
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    .onAppear { phase = 1.5 }
                }
            }
            .accessibilityHidden(true)
    }
}
