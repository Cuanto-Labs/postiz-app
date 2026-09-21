import AVKit
import SocialsCore
import SwiftUI

/// AI video generation: type/output params, credits meter, generate button (mirrors web's
/// `ai.video.tsx`). The generated video is already saved to the media library server-side
/// (`AIMediaResult`), played back inline from its `path` via `AVPlayer`. `onGenerated` lets the
/// caller (e.g. the composer) attach it. Out-of-credits and not-in-plan states are plain status
/// text, with no store link or call to action to change plans (VISION decision 8 — AI limits
/// reuse the web backend's existing plan/credit gate).
struct AIVideoView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var environment
    let viewModel: AIVideoViewModel
    var onGenerated: (AIMediaResult) -> Void = { _ in }

    @State private var videoType = ""
    @State private var output = "vertical"

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let credits = viewModel.credits {
                        AICreditsMeter(credits: credits)
                            .aiCreditsPulse(trigger: credits)
                    }

                    TextField("Video type identifier", text: $videoType)
                        .accessibilityLabel("Video type")

                    Picker("Orientation", selection: $output) {
                        Text("Vertical").tag("vertical")
                        Text("Horizontal").tag("horizontal")
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Video orientation")

                    Button("Generate") {
                        Task { await viewModel.generate(type: videoType, output: output) }
                    }
                    .disabled(isGenerateDisabled)
                    .accessibilityLabel("Generate AI video")
                }

                switch viewModel.phase {
                case .idle, .loadingCredits:
                    Section {
                        AIShimmerView(height: 32)
                            .accessibilityLabel("Loading credits")
                    }

                case .generating:
                    Section {
                        AIShimmerView(height: 240, cornerRadius: 8)
                            .accessibilityLabel("Generating video")
                    }

                case .generated(let result):
                    Section {
                        if let url = URL(string: result.path) {
                            VideoPlayer(player: AVPlayer(url: url))
                                .frame(height: 240)
                                .accessibilityLabel(result.name ?? "Generated video")
                                .aiStaggeredEntrance(index: 0, value: result)
                        }

                        Button("Use this video") {
                            onGenerated(result)
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityLabel("Use this generated video")
                    }
                    .aiResultHaptic(success: true, trigger: result)

                case .outOfCredits:
                    Section {
                        Text("You're out of AI video credits for this billing period.")
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                            .accessibilityLabel("Out of AI video credits")
                    }

                case .notInPlan:
                    Section {
                        Text("AI video generation isn't included in your current plan.")
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                            .accessibilityLabel("AI video generation not available on this plan")
                    }

                case .failed(let message) where !message.isEmpty:
                    Section {
                        Text(message)
                            .foregroundStyle(.red)
                            .font(.footnote)
                            .accessibilityLabel("AI video error")
                    }

                case .ready, .consentRequired, .failed:
                    EmptyView()
                }
            }
            .navigationTitle("AI video")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityLabel("Cancel")
                }
            }
            .task {
                if viewModel.phase == .idle {
                    await viewModel.loadCredits()
                }
            }
            .sheet(
                isPresented: Binding(
                    get: { viewModel.phase == .consentRequired },
                    set: { isPresented in if !isPresented { viewModel.reset() } }
                )
            ) {
                AIConsentSheet(viewModel: AIConsentViewModel(api: environment.api))
            }
        }
    }

    private var isGenerateDisabled: Bool {
        switch viewModel.phase {
        case .generating, .outOfCredits, .notInPlan: return true
        default: return videoType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}
