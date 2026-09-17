import SocialsCore
import SwiftUI

/// Signed-in device/session list. Owns one `DevicesViewModel`, wired to the app's real
/// `SocialsAPI` + `SessionStore` from `AppEnvironment`. Marks the current session, swipe-to-revoke
/// on the rest; revoking the current device signs out and the environment's auth gate takes over.
struct DevicesView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: DevicesViewModel?

    var body: some View {
        Group {
            if let viewModel {
                content(for: viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Devices")
        .task {
            if viewModel == nil {
                let viewModel = DevicesViewModel(
                    api: environment.api, sessionStore: environment.sessionStore)
                self.viewModel = viewModel
                await viewModel.load()
            }
        }
    }

    @ViewBuilder
    private func content(for viewModel: DevicesViewModel) -> some View {
        List {
            ForEach(viewModel.devices, id: \.id) { device in
                deviceRow(device, viewModel: viewModel)
            }

            if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.footnote)
                    .accessibilityLabel("Devices error")
            }
        }
        .overlay {
            if viewModel.isLoading && viewModel.devices.isEmpty {
                ProgressView()
            }
        }
        .refreshable {
            await viewModel.load()
        }
    }

    @ViewBuilder
    private func deviceRow(_ device: MobileSession, viewModel: DevicesViewModel) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(device.deviceName ?? "Unknown device")
                    .font(.body)
                Text("Last used \(device.lastUsedAt)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if device.current {
                Text("This device")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Current device")
            }
        }
        .swipeActions {
            Button("Revoke", role: .destructive) {
                Task { await viewModel.revoke(id: device.id) }
            }
            .accessibilityLabel("Revoke \(device.deviceName ?? "device")")
        }
    }
}
