import SocialsCore
import SwiftUI

/// Invite-a-member form. Mirrors web's `AddMember`: email (only shown when sendEmail is on),
/// role picker (USER|ADMIN), and a "Send invitation via email?" toggle — default OFF in-app, so
/// the invite link is copied rather than emailed unless the user opts in.
struct AddTeamMemberSheet: View {
    let viewModel: TeamViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var role: TeamRole = .user
    @State private var sendEmail = false
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            Form {
                if sendEmail {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .accessibilityLabel("Email")
                }

                Picker("Role", selection: $role) {
                    Text("User").tag(TeamRole.user)
                    Text("Admin").tag(TeamRole.admin)
                }
                .accessibilityLabel("Role")

                Toggle("Send invitation via email?", isOn: $sendEmail)
                    .accessibilityLabel("Send invitation via email")

                if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                        .accessibilityLabel("Invite error")
                }
            }
            .navigationTitle("Add Member")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(sendEmail ? "Send Invitation Link" : "Copy Link") {
                        isSubmitting = true
                        Task {
                            await viewModel.invite(
                                email: email, role: role, sendEmail: sendEmail)
                            isSubmitting = false
                            if viewModel.errorMessage == nil {
                                dismiss()
                            }
                        }
                    }
                    .disabled(isSubmitting || (sendEmail && email.isEmpty))
                }
            }
        }
    }
}
