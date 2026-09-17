import SocialsCore
import SwiftUI

/// Renders any `ProviderSettingsSchema` generically by switching over `ProviderSettingsField.Kind`
/// — no provider name ever appears here, the catalog (`ProviderSettingsCatalogA`/`B`) is the only
/// place that knows which fields a given provider has. Mirrors `ChannelSettingsSheet`'s
/// `List`/`Section` structure. `values` is the raw string form state, keyed by
/// `ProviderSettingsField.key`, owned by the caller (e.g. the composer's per-channel customize
/// sheet) so it can be persisted/validated alongside the rest of that channel's draft.
struct ProviderSettingsFormView: View {
    let schema: ProviderSettingsSchema
    @Binding var values: [String: String]
    var errors: [ProviderSettingsValidationError] = []

    var body: some View {
        Section {
            ForEach(schema.visibleFields(for: values)) { field in
                fieldRow(field)
            }
        } header: {
            Text("Provider settings")
        }
    }

    @ViewBuilder
    private func fieldRow(_ field: ProviderSettingsField) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            control(for: field)

            if let helpText = field.helpText {
                Text(helpText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let message = errorMessage(for: field) {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder
    private func control(for field: ProviderSettingsField) -> some View {
        switch field.kind {
        case .text(let maxLength):
            TextField(label(for: field), text: binding(for: field.key))
                .accessibilityLabel(field.label)
            if let maxLength {
                characterCount(for: field.key, limit: maxLength)
            }
        case .multilineText(let maxLength):
            TextEditor(text: binding(for: field.key))
                .frame(minHeight: 80)
                .accessibilityLabel(field.label)
            if let maxLength {
                characterCount(for: field.key, limit: maxLength)
            }
        case .url:
            TextField(label(for: field), text: binding(for: field.key))
                #if os(iOS)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                #endif
                .autocorrectionDisabled()
                .accessibilityLabel(field.label)
        case .toggle:
            Toggle(field.label, isOn: boolBinding(for: field.key))
                .accessibilityLabel(field.label)
        case .number(let min, let max):
            TextField(label(for: field), text: binding(for: field.key))
                #if os(iOS)
                    .keyboardType(.decimalPad)
                #endif
                .accessibilityLabel(field.label)
            if min != nil || max != nil {
                rangeHint(min: min, max: max)
            }
        case .singleSelect(let options):
            Picker(field.label, selection: binding(for: field.key)) {
                Text("Choose \(field.label)").tag("")
                ForEach(options) { option in
                    Text(option.label).tag(option.value)
                }
            }
            .accessibilityLabel(field.label)
        }
    }

    private func label(for field: ProviderSettingsField) -> String {
        field.isRequired ? "\(field.label) (required)" : field.label
    }

    @ViewBuilder
    private func characterCount(for key: String, limit: Int) -> some View {
        Text("\((values[key] ?? "").count)/\(limit)")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func rangeHint(min: Double?, max: Double?) -> some View {
        switch (min, max) {
        case (.some(let min), .some(let max)):
            Text("Between \(min.formatted()) and \(max.formatted())")
                .font(.caption)
                .foregroundStyle(.secondary)
        case (.some(let min), nil):
            Text("At least \(min.formatted())")
                .font(.caption)
                .foregroundStyle(.secondary)
        case (nil, .some(let max)):
            Text("At most \(max.formatted())")
                .font(.caption)
                .foregroundStyle(.secondary)
        case (nil, nil):
            EmptyView()
        }
    }

    private func errorMessage(for field: ProviderSettingsField) -> String? {
        for error in errors {
            switch error {
            case .missingRequiredField(let key) where key == field.key:
                return "\(field.label) is required."
            case .tooLong(let key, let limit) where key == field.key:
                return "\(field.label) must be \(limit) characters or fewer."
            case .invalidURL(let key) where key == field.key:
                return "\(field.label) must be a valid URL."
            case .invalidNumber(let key) where key == field.key:
                return "\(field.label) must be a number."
            case .outOfRange(let key, _, _) where key == field.key:
                return "\(field.label) is out of range."
            case .invalidSelection(let key) where key == field.key:
                return "\(field.label) has an invalid selection."
            default:
                continue
            }
        }
        return nil
    }

    private func binding(for key: String) -> Binding<String> {
        Binding(
            get: { values[key] ?? "" },
            set: { values[key] = $0 })
    }

    private func boolBinding(for key: String) -> Binding<Bool> {
        Binding(
            get: { values[key] == "true" },
            set: { values[key] = $0 ? "true" : "false" })
    }
}
