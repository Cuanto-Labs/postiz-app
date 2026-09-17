import SocialsCore
import SwiftUI

/// Per-channel analytics: channel picker, 7/30/90 range selector, one `AnalyticsSeriesCard` per
/// series. Mirrors web's `analytics.component.tsx` channel + date selection. Owns one
/// `AnalyticsViewModel`, wired to the app's real `SocialsAPI` from `AppEnvironment`.
struct AnalyticsView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: AnalyticsViewModel?

    var body: some View {
        Group {
            if let viewModel {
                content(for: viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Analytics")
        .task {
            if viewModel == nil {
                let viewModel = AnalyticsViewModel(api: environment.api)
                self.viewModel = viewModel
                await viewModel.load()
            }
        }
    }

    @ViewBuilder
    private func content(for viewModel: AnalyticsViewModel) -> some View {
        if viewModel.channels.isEmpty && !viewModel.isLoading {
            emptyChannelsState
        } else {
            VStack(spacing: 12) {
                Picker(
                    "Channel",
                    selection: Binding(
                        get: { viewModel.selectedChannelId ?? "" },
                        set: { newValue in
                            Task { await viewModel.select(channelId: newValue) }
                        })
                ) {
                    ForEach(viewModel.channels, id: \.internalId) { channel in
                        Text(channel.name).tag(channel.internalId)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityLabel("Channel")

                AnalyticsRangePicker(selection: viewModel.range) { newRange in
                    Task { await viewModel.setRange(newRange) }
                }

                body(for: viewModel)
            }
            .padding(.horizontal)
            .overlay {
                if viewModel.isLoading && viewModel.series.isEmpty {
                    ProgressView()
                }
            }
            .refreshable {
                await viewModel.load()
            }
        }
    }

    @ViewBuilder
    private func body(for viewModel: AnalyticsViewModel) -> some View {
        if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
            VStack(spacing: 8) {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.footnote)
                    .accessibilityLabel("Analytics error")
                Button("Retry") {
                    Task { await viewModel.retry() }
                }
            }
            .padding(.top, 24)
        } else if viewModel.isEmpty {
            emptySeriesState
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.series, id: \.label) { series in
                        AnalyticsSeriesCard(series: series)
                    }
                }
                .padding(.vertical)
            }
        }
    }

    private var emptyChannelsState: some View {
        ContentUnavailableView(
            "No connected channels", systemImage: "chart.bar.xaxis",
            description: Text("Connect a channel to see analytics."))
    }

    private var emptySeriesState: some View {
        ContentUnavailableView(
            "No analytics yet", systemImage: "chart.line.uptrend.xyaxis",
            description: Text("This channel doesn't have analytics for this range."))
    }
}
