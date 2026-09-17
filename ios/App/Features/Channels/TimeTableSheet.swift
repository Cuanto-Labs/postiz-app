import SocialsCore
import SwiftUI

/// Posting-time table for one channel: pick a time of day, add/remove slots, save. Mirrors
/// web's channel "posting times" table (`ChannelTimeRequest`/minutes-from-midnight slots).
struct TimeTableSheet: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: ChannelSettingsViewModel

    @State private var newSlotDate = Date()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(viewModel.timeSlots, id: \.self) { minutes in
                        Text(Self.label(forMinutesFromMidnight: minutes))
                            .accessibilityLabel(
                                "Posting time \(Self.label(forMinutesFromMidnight: minutes))")
                    }
                    .onDelete { offsets in
                        viewModel.removeTimeSlot(at: offsets)
                    }
                } header: {
                    Text("Posting times")
                }

                Section {
                    DatePicker(
                        "New time", selection: $newSlotDate, displayedComponents: .hourAndMinute
                    )
                    .accessibilityLabel("New posting time")

                    Button("Add time") {
                        viewModel.addTimeSlot(minutesFromMidnight: Self.minutesFromMidnight(newSlotDate))
                    }
                    .accessibilityLabel("Add posting time")
                }

                if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                        .accessibilityLabel("Posting times error")
                }
            }
            .navigationTitle("Time table")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityLabel("Cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Button("Save") {
                            Task {
                                await viewModel.saveTimeSlots()
                                if viewModel.errorMessage == nil || viewModel.errorMessage == "" {
                                    dismiss()
                                }
                            }
                        }
                        .accessibilityLabel("Save posting times")
                    }
                }
            }
        }
    }

    private static func minutesFromMidnight(_ date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private static func label(forMinutesFromMidnight minutes: Int) -> String {
        let hour = minutes / 60
        let minute = minutes % 60
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let date = Calendar.current.date(from: components) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }
}
