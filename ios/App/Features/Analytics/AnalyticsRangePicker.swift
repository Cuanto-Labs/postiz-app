import SocialsCore
import SwiftUI

/// 7/30/90-day range selector (mirrors web's analytics date selector). Notifies `onSelect` only
/// when the range actually changes so the owning view can drive the VM's async refetch.
struct AnalyticsRangePicker: View {
    let selection: AnalyticsRange
    let onSelect: (AnalyticsRange) -> Void

    var body: some View {
        Picker(
            "Range",
            selection: Binding(
                get: { selection },
                set: { newValue in
                    guard newValue != selection else { return }
                    onSelect(newValue)
                })
        ) {
            Text("7 days").tag(AnalyticsRange.sevenDays)
            Text("30 days").tag(AnalyticsRange.thirtyDays)
            Text("90 days").tag(AnalyticsRange.ninetyDays)
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Date range")
    }
}
