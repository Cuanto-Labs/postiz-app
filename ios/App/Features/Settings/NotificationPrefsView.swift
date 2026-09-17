import SocialsCore
import SwiftUI
import UIKit
import UserNotifications

/// Notification preferences: push per-`PushCategory` toggles (device token permitting) plus the
/// three email toggles, mirroring the web `email-notifications.component.tsx`. Owns one
/// `NotificationPrefsViewModel`, wired to the app's real `SocialsAPI` from `AppEnvironment`.
struct NotificationPrefsView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: NotificationPrefsViewModel?
    @State private var pushRegistration: PushRegistrationViewModel?
    @State private var isRequestingPushPermission = false

    var body: some View {
        Group {
            if let viewModel {
                content(for: viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Notifications")
        .task {
            if viewModel == nil {
                let pushRegistration = PushRegistrationViewModel(api: environment.api)
                self.pushRegistration = pushRegistration
                let viewModel = NotificationPrefsViewModel(api: environment.api)
                self.viewModel = viewModel
                await viewModel.load(token: pushRegistration.registeredToken)
            }
        }
    }

    @ViewBuilder
    private func content(for viewModel: NotificationPrefsViewModel) -> some View {
        @Bindable var viewModel = viewModel
        Form {
            Section("Push notifications") {
                if let pushRegistration, pushRegistration.registeredToken != nil {
                    ForEach(PushCategory.allCases, id: \.self) { category in
                        Toggle(
                            title(for: category),
                            isOn: Binding(
                                get: { viewModel.isPushEnabled(category) },
                                set: { newValue in
                                    Task { await viewModel.togglePush(category, on: newValue) }
                                }
                            )
                        )
                        .accessibilityLabel(title(for: category))
                    }
                } else {
                    Button {
                        Task { await requestPushPermission() }
                    } label: {
                        if isRequestingPushPermission {
                            ProgressView()
                        } else {
                            Text("Enable notifications")
                        }
                    }
                    .disabled(isRequestingPushPermission)
                    .accessibilityLabel("Enable notifications")
                }
            }

            Section("Email notifications") {
                Toggle(
                    "Success emails",
                    isOn: Binding(
                        get: { viewModel.sendSuccessEmails },
                        set: { newValue in
                            Task { await viewModel.toggleEmail(.success, on: newValue) }
                        }
                    )
                )
                .accessibilityLabel("Success emails")

                Toggle(
                    "Failure emails",
                    isOn: Binding(
                        get: { viewModel.sendFailureEmails },
                        set: { newValue in
                            Task { await viewModel.toggleEmail(.failure, on: newValue) }
                        }
                    )
                )
                .accessibilityLabel("Failure emails")

                Toggle(
                    "Streak emails",
                    isOn: Binding(
                        get: { viewModel.sendStreakEmails },
                        set: { newValue in
                            Task { await viewModel.toggleEmail(.streak, on: newValue) }
                        }
                    )
                )
                .accessibilityLabel("Streak emails")
            }

            if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                        .accessibilityLabel("Notification preferences error")
                }
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
    }

    private func title(for category: PushCategory) -> String {
        switch category {
        case .postPublished: return "Post published"
        case .postFailed: return "Post failed"
        case .channelReconnect: return "Channel needs reconnecting"
        }
    }

    /// Requests system notification permission and registers for remote notifications. The
    /// resulting device token flows back through the app's push-registration plumbing
    /// (`PushRegistrationViewModel.didReceiveToken`); registering the device with `SocialsAPI`
    /// is out of scope here.
    private func requestPushPermission() async {
        isRequestingPushPermission = true
        defer { isRequestingPushPermission = false }
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge])
        UIApplication.shared.registerForRemoteNotifications()
    }
}
