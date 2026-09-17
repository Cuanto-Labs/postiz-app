import SocialsCore
import SwiftUI

/// Team member list. Owns one `TeamViewModel`, wired to the app's real `SocialsAPI` from
/// `AppEnvironment`. Mirrors web's `teams.component.tsx`: role label per row, swipe-to-remove
/// with a confirmation alert, "Add member" opens `AddTeamMemberSheet`.
struct TeamView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: TeamViewModel?
    @State private var showingAddMember = false
    @State private var memberPendingRemoval: TeamMember?

    var body: some View {
        Group {
            if let viewModel {
                content(for: viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Team Members")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add member") {
                    showingAddMember = true
                }
                .accessibilityLabel("Add another member")
            }
        }
        .sheet(isPresented: $showingAddMember) {
            if let viewModel {
                AddTeamMemberSheet(viewModel: viewModel)
            }
        }
        .task {
            if viewModel == nil {
                let viewModel = TeamViewModel(api: environment.api)
                self.viewModel = viewModel
                await viewModel.load()
            }
        }
    }

    @ViewBuilder
    private func content(for viewModel: TeamViewModel) -> some View {
        List {
            ForEach(viewModel.members, id: \.user.id) { member in
                memberRow(member, viewModel: viewModel)
            }

            if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.footnote)
                    .accessibilityLabel("Team error")
            }
        }
        .overlay {
            if viewModel.isLoading && viewModel.members.isEmpty {
                ProgressView()
            }
        }
        .refreshable {
            await viewModel.load()
        }
        .alert(
            "Remove team member?",
            isPresented: Binding(
                get: { memberPendingRemoval != nil },
                set: { if !$0 { memberPendingRemoval = nil } })
        ) {
            Button("Cancel", role: .cancel) {
                memberPendingRemoval = nil
            }
            Button("Remove", role: .destructive) {
                if let member = memberPendingRemoval {
                    Task { await viewModel.remove(id: member.user.id) }
                }
                memberPendingRemoval = nil
            }
        } message: {
            Text("Are you sure you want to remove this team member?")
        }
    }

    @ViewBuilder
    private func memberRow(_ member: TeamMember, viewModel: TeamViewModel) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(member.user.email)
                    .font(.body)
                Text(roleLabel(member.role))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .swipeActions {
            Button("Remove", role: .destructive) {
                memberPendingRemoval = member
            }
            .accessibilityLabel("Remove \(member.user.email)")
        }
    }

    private func roleLabel(_ role: String) -> String {
        switch role {
        case TeamRole.user.rawValue: return "User"
        case TeamRole.admin.rawValue: return "Admin"
        default: return "Super Admin"
        }
    }
}
