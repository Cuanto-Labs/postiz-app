import SocialsCore
import SwiftUI

/// Toolbar menu for switching the active org. Owns one `OrgSwitcherViewModel`, wired to the
/// app's real `SocialsAPI` + `SessionStore` from `AppEnvironment`. Drop into a `.toolbar {
/// ToolbarItem { OrgSwitcherMenu() } }`.
struct OrgSwitcherMenu: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: OrgSwitcherViewModel?

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
                let viewModel = OrgSwitcherViewModel(
                    api: environment.api, sessionStore: environment.sessionStore)
                self.viewModel = viewModel
                await viewModel.load()
            }
        }
    }

    @ViewBuilder
    private func content(for viewModel: OrgSwitcherViewModel) -> some View {
        Menu {
            ForEach(viewModel.orgs, id: \.id) { org in
                Button {
                    Task { await viewModel.selectOrg(org.id) }
                } label: {
                    if org.id == viewModel.currentOrgId {
                        Label(org.name, systemImage: "checkmark")
                    } else {
                        Text(org.name)
                    }
                }
                .disabled(org.disabled)
                .accessibilityLabel("Switch to \(org.name)")
            }
        } label: {
            if viewModel.isLoading {
                ProgressView()
            } else {
                Label(currentOrgName(viewModel), systemImage: "chevron.down.circle")
            }
        }
        .accessibilityLabel("Organization switcher")
    }

    private func currentOrgName(_ viewModel: OrgSwitcherViewModel) -> String {
        viewModel.orgs.first(where: { $0.id == viewModel.currentOrgId })?.name ?? "Select org"
    }
}
