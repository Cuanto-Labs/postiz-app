import SocialsCore
import SwiftUI

/// AI media handoff: shares one `matchedGeometryEffect` between the "Use this" thumbnail in
/// `AIImageView`/`AIVideoView` and its landing spot in the composer's `MediaTrayView`, so the
/// generated result appears to fly from the AI sheet into the tray (VISION decision 9). Falls
/// back to a plain cross-fade under Reduce Motion, mirroring `AIMotion.swift`'s style.
enum AIMediaHandoffNamespace {
    /// Geometry id shared by the source ("Use this" thumbnail) and destination (tray thumbnail)
    /// views for a given result, so `matchedGeometryEffect` matches the right pair even if
    /// several results could be in flight.
    static func id(for result: AIMediaResult) -> String {
        "ai-media-handoff-\(result.id)"
    }
}

extension View {
    /// Marks a view as the flight's origin: the "Use this" thumbnail inside `AIImageView`/
    /// `AIVideoView`.
    func aiMediaHandoffSource(_ result: AIMediaResult, in namespace: Namespace.ID) -> some View {
        modifier(AIMediaHandoffModifier(result: result, namespace: namespace, isSource: true))
    }

    /// Marks a view as the flight's destination: the landing thumbnail inside `MediaTrayView`,
    /// which then calls `attachAIMedia` once the result lands.
    func aiMediaHandoffDestination(_ result: AIMediaResult, in namespace: Namespace.ID) -> some View {
        modifier(AIMediaHandoffModifier(result: result, namespace: namespace, isSource: false))
    }
}

private struct AIMediaHandoffModifier: ViewModifier {
    let result: AIMediaResult
    let namespace: Namespace.ID
    let isSource: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content.transition(.opacity)
        } else {
            content.matchedGeometryEffect(
                id: AIMediaHandoffNamespace.id(for: result), in: namespace, isSource: isSource)
        }
    }
}
