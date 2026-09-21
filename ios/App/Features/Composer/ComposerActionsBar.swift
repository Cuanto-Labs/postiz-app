import SocialsCore
import SwiftUI

/// Composer bottom actions bar: creating a new post shows Save draft / Add to calendar /
/// Post now; editing an existing one (`ComposerViewModel.existingGroup` set) swaps in Update /
/// Delete. Mirrors web's `add.edit.modal.tsx` footer buttons plus the calendar's edit/delete
/// post actions, collapsed into the composer per docs/IOS-APP-PLAN.md §5.3.
struct ComposerActionsBar: View {
    @Environment(\.dismiss) private var dismiss

    let viewModel: ComposerViewModel
    let onSchedule: () -> Void
    let onDeleted: () -> Void

    @State private var showDeleteConfirm = false

    private var isEditing: Bool { viewModel.existingGroup != nil }

    var body: some View {
        HStack(spacing: 12) {
            if isEditing {
                deleteButton
                Spacer()
                if viewModel.isSaving {
                    ProgressView()
                } else {
                    updateButton
                }
            } else {
                saveDraftButton
                Spacer()
                scheduleButton
                if viewModel.isSaving {
                    ProgressView()
                } else {
                    postNowButton
                }
            }
        }
        .disabled(viewModel.isSaving)
        .confirmationDialog(
            "Are you sure you want to delete this post?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task {
                    if await viewModel.delete() { onDeleted() }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var saveDraftButton: some View {
        Button("Save draft") {
            Task { if await viewModel.submit(type: "draft") { dismiss() } }
        }
        .disabled(!viewModel.isValid)
        .accessibilityLabel("Save draft")
    }

    private var scheduleButton: some View {
        Button("Add to calendar", action: onSchedule)
            .disabled(!viewModel.isValid)
            .accessibilityLabel("Add to calendar")
    }

    private var postNowButton: some View {
        Button("Post now") {
            Task { if await viewModel.submit(type: "now") { dismiss() } }
        }
        .buttonStyle(.borderedProminent)
        .disabled(!viewModel.isValid)
        .accessibilityLabel("Post now")
    }

    private var updateButton: some View {
        Button("Update") {
            Task {
                let type = viewModel.scheduleDate == nil ? "now" : "schedule"
                if await viewModel.submit(type: type, date: viewModel.scheduleDate) {
                    dismiss()
                }
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(!viewModel.isValid)
        .accessibilityLabel("Update")
    }

    private var deleteButton: some View {
        Button("Delete", role: .destructive) { showDeleteConfirm = true }
            .accessibilityLabel("Delete post")
    }
}
