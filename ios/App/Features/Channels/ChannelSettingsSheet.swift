import SocialsCore
import SwiftUI

/// Per-channel settings: customer assignment (autocomplete), move to group, posting-time table
/// (via `TimeTableSheet`), and raw provider preferences. Mirrors web's channel settings panel
/// (customer picker, group field, time table, provider-specific settings JSON).
struct ChannelSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ChannelSettingsViewModel
    @State private var customerNameInput: String
    @State private var groupInput = ""
    @State private var providerSettingsInput = ""
    @State private var showTimeTable = false

    init(api: any SocialsAPI, channel: ChannelDTO) {
        _viewModel = State(initialValue: ChannelSettingsViewModel(api: api, channel: channel))
        _customerNameInput = State(initialValue: channel.customer?.name ?? "")
    }

    var body: some View {
        NavigationStack {
            List {
                customerSection
                groupSection
                timeTableSection
                providerPreferencesSection

                if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                        .accessibilityLabel("Channel settings error")
                }
            }
            .navigationTitle(viewModel.channel.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityLabel("Done")
                }
            }
            .task {
                await viewModel.loadCustomers()
            }
            .sheet(isPresented: $showTimeTable) {
                TimeTableSheet(viewModel: viewModel)
            }
        }
    }

    @ViewBuilder
    private var customerSection: some View {
        Section {
            TextField("Customer name", text: $customerNameInput)
                .accessibilityLabel("Customer name")

            let suggestions = viewModel.customerSuggestions(matching: customerNameInput)
            if !customerNameInput.isEmpty, !suggestions.isEmpty {
                ForEach(suggestions, id: \.id) { customer in
                    Button(customer.name) {
                        customerNameInput = customer.name
                    }
                    .accessibilityLabel("Use customer \(customer.name)")
                }
            }

            saveButton("Save customer") {
                await viewModel.saveCustomerName(customerNameInput)
            }
        } header: {
            Text("Customer")
        }
    }

    @ViewBuilder
    private var groupSection: some View {
        Section {
            TextField("Group", text: $groupInput)
                .accessibilityLabel("Group name")

            saveButton("Move to group") {
                await viewModel.saveGroup(groupInput)
            }
        } header: {
            Text("Group")
        }
    }

    @ViewBuilder
    private var timeTableSection: some View {
        Section {
            Button("Edit posting times") {
                showTimeTable = true
            }
            .accessibilityLabel("Edit posting times")
        } header: {
            Text("Time table")
        }
    }

    @ViewBuilder
    private var providerPreferencesSection: some View {
        Section {
            TextEditor(text: $providerSettingsInput)
                .frame(minHeight: 100)
                .accessibilityLabel("Provider preferences")

            saveButton("Save preferences") {
                await viewModel.saveProviderSettings(additionalSettings: providerSettingsInput)
            }
        } header: {
            Text("Provider preferences")
        }
    }

    @ViewBuilder
    private func saveButton(_ title: String, action: @escaping () async -> Void) -> some View {
        if viewModel.isSaving {
            ProgressView()
        } else {
            Button(title) { Task { await action() } }
                .accessibilityLabel(title)
        }
    }
}
