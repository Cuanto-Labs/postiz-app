import SocialsCore
import SwiftUI
import UIKit

/// Sign-up screen: email, password, company, and an optional invite code. Owns one
/// `RegisterViewModel`, wired to the app's real `SocialsAPI` + `SessionStore` from
/// `AppEnvironment`. Mirrors `SignInView`'s structure.
struct RegisterView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: RegisterViewModel?
    @FocusState private var focusedField: Field?

    private enum Field {
        case email, password, company, inviteCode
    }

    var body: some View {
        Group {
            if let viewModel {
                content(for: viewModel)
            } else {
                ProgressView()
            }
        }
        .task {
            if viewModel == nil {
                viewModel = RegisterViewModel(
                    api: environment.api,
                    sessionStore: environment.sessionStore,
                    deviceId: Self.deviceId(),
                    deviceName: UIDevice.current.name)
            }
        }
    }

    @ViewBuilder
    private func content(for viewModel: RegisterViewModel) -> some View {
        @Bindable var viewModel = viewModel
        ScrollView {
            VStack(spacing: 20) {
                Text("Create account")
                    .font(.largeTitle.bold())

                if viewModel.needsActivation {
                    Text("Check your email to activate your account.")
                        .font(.footnote)
                        .accessibilityLabel("Activation required")
                } else {
                    VStack(spacing: 12) {
                        TextField("Email", text: $viewModel.email)
                            .textContentType(.username)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .email)
                            .accessibilityLabel("Email")

                        SecureField("Password", text: $viewModel.password)
                            .textContentType(.newPassword)
                            .focused($focusedField, equals: .password)
                            .accessibilityLabel("Password")

                        TextField("Company", text: $viewModel.company)
                            .textContentType(.organizationName)
                            .focused($focusedField, equals: .company)
                            .accessibilityLabel("Company")

                        TextField("Invite code (optional)", text: $viewModel.inviteCode)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .inviteCode)
                            .accessibilityLabel("Invite code")
                    }
                    .textFieldStyle(.roundedBorder)

                    if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                            .accessibilityLabel("Registration error")
                    }

                    Button {
                        focusedField = nil
                        Task { await viewModel.register() }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Text("Create account")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canSubmit || viewModel.isLoading)
                    .accessibilityLabel("Create account")
                }
            }
            .padding()
        }
    }

    /// Stable per-install identifier for `RegisterViewModel`'s `deviceId`. Mirrors
    /// `SignInView.deviceId()`.
    private static func deviceId() -> String {
        UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
    }
}
