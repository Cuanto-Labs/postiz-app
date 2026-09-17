import SocialsCore
import SwiftUI

/// AI copilot text assist: rewrite the post ("variations") or shorten it to fit a length limit
/// ("fit"), mirroring web's copilot rewrite flow (`POST /mobile/v1/ai/suggest`). Motion follows
/// VISION decision 9: a shimmer skeleton while waiting, suggestions enter with a staggered
/// spring, and picking one uses a shared `matchedGeometryEffect` so it reads as one continuous
/// motion into the caller's text field. Plan/credit gating reuses the web backend's existing
/// mechanism (VISION decision 8) and is surfaced here only as a plain status message — no store
/// link, no call to action to change plans.
struct CopilotSheet: View {
    @Environment(\.dismiss) private var dismiss
    let content: String
    let viewModel: CopilotViewModel
    var onApply: (String) -> Void = { _ in }

    @State private var mode: AISuggestMode = .variations
    @State private var maxLength = 280
    @Namespace private var suggestionSpace

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Mode", selection: $mode) {
                        Text("Rewrite").tag(AISuggestMode.variations)
                        Text("Fit to length").tag(AISuggestMode.fit)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Suggestion mode")

                    if mode == .fit {
                        Stepper("Max length: \(maxLength)", value: $maxLength, in: 1...10000)
                            .accessibilityLabel("Maximum length \(maxLength) characters")
                    }

                    Button("Get suggestions") {
                        Task {
                            await viewModel.suggest(
                                content: content, mode: mode,
                                maxLength: mode == .fit ? maxLength : nil)
                        }
                    }
                    .disabled(viewModel.isLoading)
                    .accessibilityLabel("Get AI suggestions")
                }

                if viewModel.isLoading {
                    Section {
                        ForEach(0..<3, id: \.self) { _ in
                            AIShimmerView()
                        }
                    }
                    .accessibilityLabel("Loading suggestions")
                }

                if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                            .accessibilityLabel("Copilot error")
                    }
                    .aiResultHaptic(success: false, trigger: errorMessage)
                }

                if viewModel.notInPlan {
                    Section {
                        Text("AI suggestions aren't included in your current plan.")
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                            .accessibilityLabel("AI suggestions not available on this plan")
                    }
                }

                if !viewModel.suggestions.isEmpty {
                    Section {
                        ForEach(Array(viewModel.suggestions.enumerated()), id: \.offset) {
                            index, suggestion in
                            CopilotSuggestionRow(text: suggestion, namespace: suggestionSpace) {
                                onApply(suggestion)
                                dismiss()
                            }
                            .aiStaggeredEntrance(index: index, value: viewModel.suggestions)
                        }
                    } header: {
                        TypewriterText(text: "Suggestions")
                    }
                    .aiResultHaptic(success: true, trigger: viewModel.suggestions)
                }
            }
            .navigationTitle("AI copilot")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityLabel("Cancel")
                }
            }
            .sheet(
                isPresented: Binding(
                    get: { viewModel.consentRequired },
                    set: { isPresented in if !isPresented { viewModel.reset() } }
                )
            ) {
                AIConsentSheet(viewModel: AIConsentViewModel(api: environmentAPI))
            }
        }
    }

    /// `AIConsentSheet` needs a `SocialsAPI`; `CopilotViewModel` doesn't expose the one it was
    /// built with, so the consent gate reads it from the environment like every other sheet does.
    @Environment(AppEnvironment.self) private var environment
    private var environmentAPI: any SocialsAPI { environment.api }
}
