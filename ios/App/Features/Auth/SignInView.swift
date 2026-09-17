import SocialsCore
import SwiftUI
import UIKit

/// Sign-in screen: email/password, Sign in with Apple (native, via `AppleSignInCoordinator`),
/// and Google (web PKCE, via `WebAuthSession`). Owns one `SignInViewModel`, wired to the app's
/// real `SocialsAPI` + `SessionStore` from `AppEnvironment`.
struct SignInView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: SignInViewModel?
    @State private var appleCoordinator = AppleSignInCoordinator()
    @State private var showRegister = false
    @FocusState private var focusedField: Field?

    /// Called once `sessionStore.state` reflects a successful sign-in (email, Apple, or
    /// Google). The view models don't expose a dedicated "succeeded" phase, so this re-reads
    /// session state after each load finishes rather than adding one — see `onLoadingChange`.
    var onSignedIn: () -> Void = {}

    private enum Field {
        case email, password
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
                viewModel = SignInViewModel(
                    api: environment.api,
                    sessionStore: environment.sessionStore,
                    deviceId: Self.deviceId(),
                    deviceName: UIDevice.current.name,
                    webAuth: WebAuthSession(),
                    callbackURLScheme: AppIdentifiers.urlScheme)
            }
        }
        .sheet(isPresented: $showRegister) {
            RegisterView(onSignedIn: {
                showRegister = false
                onSignedIn()
            })
        }
    }

    private func onLoadingChange(_ isLoading: Bool) {
        guard !isLoading else { return }
        Task {
            if case .signedIn = await environment.sessionStore.state {
                onSignedIn()
            }
        }
    }

    @ViewBuilder
    private func content(for viewModel: SignInViewModel) -> some View {
        @Bindable var viewModel = viewModel
        ScrollView {
            VStack(spacing: 20) {
                Text("Sign in")
                    .font(.largeTitle.bold())

                VStack(spacing: 12) {
                    TextField("Email", text: $viewModel.email)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .email)
                        .accessibilityLabel("Email")
                        .accessibilityIdentifier("signIn.email")

                    SecureField("Password", text: $viewModel.password)
                        .textContentType(.password)
                        .focused($focusedField, equals: .password)
                        .accessibilityLabel("Password")
                        .accessibilityIdentifier("signIn.password")
                }
                .textFieldStyle(.roundedBorder)

                if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                        .accessibilityLabel("Sign-in error")
                }

                Button {
                    focusedField = nil
                    Task { await viewModel.signInWithEmail() }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Text("Sign in")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canSubmitEmail || viewModel.isLoading)
                .accessibilityLabel("Sign in with email")
                .accessibilityIdentifier("signIn.submit")

                Button {
                    Task {
                        guard let result = try? await appleCoordinator.signIn() else { return }
                        await viewModel.signInWithApple(result)
                    }
                } label: {
                    Label("Continue with Apple", systemImage: "apple.logo")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isLoading)
                .accessibilityLabel("Sign in with Apple")

                Button {
                    Task { await viewModel.signInWithGoogle() }
                } label: {
                    Text("Continue with Google")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isLoading)
                .accessibilityLabel("Sign in with Google")

                Button("Create an account") {
                    showRegister = true
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isLoading)
                .accessibilityLabel("Create an account")
                .accessibilityIdentifier("signIn.registerLink")
            }
            .padding()
        }
        .onChange(of: viewModel.isLoading, initial: false) { _, isLoading in
            onLoadingChange(isLoading)
        }
    }

    /// Stable per-install identifier for `SignInViewModel`'s `deviceId`. `identifierForVendor`
    /// is stable across launches for this app on this device; a random fallback covers the rare
    /// case where the OS hasn't assigned one yet.
    private static func deviceId() -> String {
        UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
    }
}
