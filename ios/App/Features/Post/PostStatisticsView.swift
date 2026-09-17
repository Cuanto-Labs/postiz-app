import SocialsCore
import SwiftUI

/// Post statistics, backed by `PostDetailViewModel.statistics`/`loadStatistics()` (mirrors web's
/// `statistics.tsx` `StatisticsModal`, which fetches `/posts/:id/statistics`). The server payload
/// isn't pinned to a fixed shape (`OpaqueJSONResult` carries the raw response), so this renders
/// whatever key/value pairs come back rather than assuming fields that may not exist.
struct PostStatisticsView: View {
    let viewModel: PostDetailViewModel

    var body: some View {
        Group {
            if viewModel.isLoadingStatistics && viewModel.statistics == nil {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let statistics = viewModel.statistics {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        let entries = Self.entries(from: statistics.raw)
                        if entries.isEmpty {
                            Text(statistics.raw)
                                .font(.footnote)
                                .accessibilityLabel("Statistics raw payload")
                        } else {
                            ForEach(entries, id: \.key) { entry in
                                HStack {
                                    Text(entry.key)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(entry.value)
                                        .fontWeight(.medium)
                                }
                                .accessibilityLabel("\(entry.key): \(entry.value)")
                            }
                        }
                    }
                    .padding()
                }
            } else if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel("Statistics error")
            } else {
                Text("No statistics available yet.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel("No statistics available")
            }
        }
        .navigationTitle("Statistics")
        .task { await viewModel.loadStatistics() }
    }

    private static func entries(from raw: String) -> [(key: String, value: String)] {
        guard let data = raw.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [] }
        return object.keys.sorted().map { key in
            (key: key, value: String(describing: object[key] ?? ""))
        }
    }
}
