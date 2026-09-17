import SocialsCore
import SwiftUI

/// Schedule picker: post now, pick a date & time, or the next free slot via
/// `ComposerViewModel.findSlot()` (`SocialsAPI.findSlot`, `GET /mobile/v1/posts/find-slot`).
/// Timezone is shown explicitly per docs/IOS-APP-PLAN.md §5.3. Repeat is out of scope for v1
/// (same doc, same section) so it is deliberately not offered here.
struct ScheduleSheet: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: ComposerViewModel
    var onScheduled: () -> Void = {}

    @State private var mode: ScheduleMode
    @State private var pickedDate: Date

    init(viewModel: ComposerViewModel, onScheduled: @escaping () -> Void = {}) {
        self.viewModel = viewModel
        self.onScheduled = onScheduled
        let existing = viewModel.scheduleDate.flatMap { ISO8601DateFormatter().date(from: $0) }
        _mode = State(initialValue: existing == nil ? .now : .pick)
        _pickedDate = State(initialValue: existing ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("When", selection: $mode) {
                        Text("Post now").tag(ScheduleMode.now)
                        Text("Pick a date & time").tag(ScheduleMode.pick)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Schedule mode")
                }

                if mode == .pick {
                    Section {
                        DatePicker("Date & time", selection: $pickedDate)
                            .accessibilityLabel("Scheduled date and time")

                        Text("Timezone: \(Self.timezoneLabel)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Timezone \(Self.timezoneLabel)")

                        if viewModel.isFindingSlot {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Button("Use next free slot") {
                                Task {
                                    await viewModel.findSlot()
                                    if let date = viewModel.scheduleDate,
                                        let parsed = ISO8601DateFormatter().date(from: date)
                                    {
                                        pickedDate = parsed
                                    }
                                }
                            }
                            .accessibilityLabel("Use next free slot")
                        }
                    }
                }

                if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                        .accessibilityLabel("Schedule error")
                }
            }
            .navigationTitle("Add to calendar")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityLabel("Cancel")
                }
                ToolbarItem(placement: .confirmationAction) { confirmButton }
            }
        }
    }

    @ViewBuilder
    private var confirmButton: some View {
        if viewModel.isSaving {
            ProgressView()
        } else {
            Button("Schedule") {
                viewModel.scheduleDate =
                    mode == .now ? nil : ISO8601DateFormatter().string(from: pickedDate)
                Task {
                    let type = mode == .now ? "now" : "schedule"
                    if await viewModel.submit(type: type, date: viewModel.scheduleDate) {
                        dismiss()
                        onScheduled()
                    }
                }
            }
            .accessibilityLabel("Confirm schedule")
        }
    }

    private static var timezoneLabel: String {
        TimeZone.current.abbreviation() ?? TimeZone.current.identifier
    }
}

private enum ScheduleMode: Hashable {
    case now
    case pick
}
