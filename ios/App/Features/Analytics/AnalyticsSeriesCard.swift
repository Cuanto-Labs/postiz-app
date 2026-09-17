import Charts
import SocialsCore
import SwiftUI

/// One `AnalyticsSeries` rendered as a Swift Charts line chart, with the series label + a
/// percentage-change arrow (mirrors web's `chart-social.tsx` card + `up.down.arrow.tsx`
/// semantics: up = positive change, down = negative).
struct AnalyticsSeriesCard: View {
    let series: AnalyticsSeries

    private var isUp: Bool {
        series.percentageChange >= 0
    }

    private var latestTotal: String {
        series.data.last?.total ?? "0"
    }

    private var changeText: String {
        String(format: "%.1f%%", abs(series.percentageChange))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // ViewThatFits: side-by-side label + change badge at normal text sizes, stacked at
            // large Dynamic Type so neither gets clipped/overlapped in the fixed-width header row.
            ViewThatFits(in: .horizontal) {
                HStack {
                    Text(series.label)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    Label(changeText, systemImage: isUp ? "arrow.up" : "arrow.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isUp ? .green : .red)
                        .lineLimit(1)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(series.label)
                        .font(.headline)
                    Label(changeText, systemImage: isUp ? "arrow.up" : "arrow.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isUp ? .green : .red)
                }
            }

            if series.data.isEmpty {
                Text("No data for this range")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Chart(series.data, id: \.date) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Total", Double(point.total) ?? 0)
                    )
                    .interpolationMethod(.catmullRom)
                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Total", Double(point.total) ?? 0)
                    )
                    .foregroundStyle(.tint.opacity(0.15))
                }
                .chartXAxis(.hidden)
                .frame(height: 120)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(series.label): latest \(latestTotal), \(isUp ? "up" : "down") \(changeText)")
    }
}
