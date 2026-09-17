import SwiftUI

/// `count/limit` readout, mirrors web's inline character counter shown under each editor
/// (`apps/frontend/src/components/new-launch/editor.tsx`) — turns red once `count` exceeds
/// `limit`, same threshold `ComposerViewModel.isOverCharLimit` uses.
struct CharacterCounterView: View {
    let count: Int
    let limit: Int

    private var isOverLimit: Bool { count > limit }

    var body: some View {
        Text("\(count)/\(limit)")
            .font(.caption)
            .foregroundStyle(isOverLimit ? .red : .secondary)
            .accessibilityLabel(
                isOverLimit
                    ? "\(count) of \(limit) characters, over limit"
                    : "\(count) of \(limit) characters")
    }
}
