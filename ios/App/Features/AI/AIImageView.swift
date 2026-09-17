import SocialsCore
import SwiftUI

/// AI image generation: prompt field, credits meter, generate button (mirrors web's
/// `ai.image.tsx`). The generated image is already saved to the media library server-side
/// (`AIMediaResult`); `onGenerated` lets the caller (e.g. the composer) attach it. Out-of-credits
/// and not-in-plan states are plain status text, with no store link or call to action to
/// change plans (VISION decision 8 — AI limits reuse the web backend's existing plan/credit
/// gate).
struct AIImageView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var environment
    let viewModel: AIImageViewModel
    var onGenerated: (AIMediaResult) -> Void = { _ in }

    @State private var prompt = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let credits = viewModel.credits {
                        AICreditsMeter(credits: credits)
                            .aiCreditsPulse(trigger: credits)
                    }

                    TextField("Describe the image you want", text: $prompt, axis: .vertical)
                        .lineLimit(3...6)
                        .accessibilityLabel("Image prompt")

                    Button("Generate") {
                        Task { await viewModel.generate(prompt: prompt) }
                    }
                    .disabled(isGenerateDisabled)
                    .accessibilityLabel("Generate AI image")
                }

                switch viewModel.phase {
                case .idle, .loadingCredits:
                    Section {
                        AIShimmerView(height: 32)
                            .accessibilityLabel("Loading credits")
                    }

                case .generating:
                    Section {
                        AIShimmerView(height: 200, cornerRadius: 8)
                            .accessibilityLabel("Generating image")
                    }

                case .generated(let result):
                    Section {
                        AsyncImage(url: URL(string: result.path)) { image in
                            image.resizable().scaledToFit()
                        } placeholder: {
                            AIShimmerView(height: 200, cornerRadius: 8)
                        }
                        .accessibilityLabel(result.name ?? "Generated image")
                        .aiStaggeredEntrance(index: 0, value: result)

                        Button("Use this image") {
                            onGenerated(result)
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityLabel("Use this generated image")
                    }
                    .aiResultHaptic(success: true, trigger: result)

                case .outOfCredits:
                    Section {
                        Text("You're out of AI image credits for this billing period.")
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                            .accessibilityLabel("Out of AI image credits")
                    }

                case .notInPlan:
                    Section {
                        Text("AI image generation isn't included in your current plan.")
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                            .accessibilityLabel("AI image generation not available on this plan")
                    }

                case .failed(let message) where !message.isEmpty:
                    Section {
                        Text(message)
                            .foregroundStyle(.red)
                            .font(.footnote)
                            .accessibilityLabel("AI image error")
                    }

                case .ready, .consentRequired, .failed:
                    EmptyView()
                }
            }
            .navigationTitle("AI image")
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
        default: return prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}
