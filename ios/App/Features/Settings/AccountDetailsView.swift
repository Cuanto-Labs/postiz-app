import SocialsCore
import SwiftUI

/// Personal profile section: full name + bio. Owns one `AccountDetailsViewModel`, wired to the
/// app's real `SocialsAPI` from `AppEnvironment`. Mirrors the web `global.settings.tsx` personal
/// form (`UserDetailDto`: `fullname` required, `bio` optional).
struct AccountDetailsView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: AccountDetailsViewModel?
    @FocusState private var focusedField: Field?

    private enum Field {
        case fullname, bio
    }

    var body: some View {
        Group {
            if let viewModel {
                content(for: viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Account details")
        .task {
            if viewModel == nil {
                let viewModel = AccountDetailsViewModel(api: environment.api)
                self.viewModel = viewModel
                await viewModel.load()
            }
        }
    }

    @ViewBuilder
    private func content(for viewModel: AccountDetailsViewModel) -> some View {
        @Bindable var viewModel = viewModel
        Form {
            Section {
                TextField("Full name", text: $viewModel.fullname)
                    .textContentType(.name)
                    .focused($focusedField, equals: .fullname)
                    .accessibilityLabel("Full name")

                TextField("Bio", text: $viewModel.bio, axis: .vertical)
                    .lineLimit(3...6)
                    .focused($focusedField, equals: .bio)
                    .accessibilityLabel("Bio")
            }

            if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                        .accessibilityLabel("Account details error")
                }
            }

            Section {
                Button {
                    focusedField = nil
                    Task { await viewModel.save() }
                } label: {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Text("Save")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(!viewModel.canSave || viewModel.isSaving)
                .accessibilityLabel("Save account details")
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
    }
}
