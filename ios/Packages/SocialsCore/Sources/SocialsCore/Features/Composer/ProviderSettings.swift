import Foundation

/// One field in a provider's per-channel settings form, mirrors a field on one of the
/// `class-validator` DTOs in
/// `libraries/nestjs-libraries/src/dtos/posts/providers-settings/*.dto.ts`. The catalog
/// (`ProviderSettingsCatalogA`/`ProviderSettingsCatalogB`) is the only place that knows which
/// fields a given provider has — `ProviderSettingsFormView` renders any `ProviderSettingsField`
/// generically, so no provider name ever appears in the rendering/validation code (repo rule:
/// no per-provider special-casing outside the provider's own file).
public struct ProviderSettingsField: Sendable, Equatable, Identifiable {
    public enum Kind: Sendable, Equatable {
        /// Single-line free text, optionally capped (mirrors `@MaxLength`).
        case text(maxLength: Int?)
        /// Multi-line free text, optionally capped.
        case multilineText(maxLength: Int?)
        /// A URL, mirrors `@IsUrl`.
        case url
        /// A boolean switch, mirrors a `boolean` DTO field.
        case toggle
        /// A numeric field with an optional inclusive range, mirrors `@Min`/`@Max`.
        case number(min: Double?, max: Double?)
        /// A single choice from a fixed set of options, mirrors `@IsIn([...])`.
        case singleSelect(options: [ProviderSettingsOption])
    }

    public let id: String
    public let key: String
    public let label: String
    public let kind: Kind
    public let isRequired: Bool
    public let helpText: String?
    /// When set, this field is only shown/required if `visibleWhen.key` currently equals
    /// `visibleWhen.value` — mirrors DTO `@ValidateIf` conditionals (e.g. X's `article_title`
    /// only applies when `post_type === 'article'`).
    public let visibleWhen: ProviderSettingsCondition?

    public init(
        key: String, label: String, kind: Kind, isRequired: Bool = false,
        helpText: String? = nil, visibleWhen: ProviderSettingsCondition? = nil
    ) {
        self.id = key
        self.key = key
        self.label = label
        self.kind = kind
        self.isRequired = isRequired
        self.helpText = helpText
        self.visibleWhen = visibleWhen
    }
}

/// One option in a `ProviderSettingsField.Kind.singleSelect` list.
public struct ProviderSettingsOption: Sendable, Equatable, Identifiable {
    public let id: String
    public let value: String
    public let label: String

    public init(value: String, label: String) {
        self.id = value
        self.value = value
        self.label = label
    }
}

/// A field-visibility/requirement condition, mirrors a DTO's `@ValidateIf((o) => o.key === value)`.
public struct ProviderSettingsCondition: Sendable, Equatable {
    public let key: String
    public let value: String

    public init(key: String, value: String) {
        self.key = key
        self.value = value
    }
}

/// The full settings form for one provider (or a family of providers sharing one DTO, e.g.
/// `linkedin`/`linkedin-page`), keyed by `providerIdentifiers` (matches `ChannelDTO.identifier`).
/// An empty `fields` array is a valid schema — several providers (threads, bluesky, mastodon,
/// telegram, nostr, vk) have no extra settings beyond the base post content.
public struct ProviderSettingsSchema: Sendable, Equatable {
    public let providerIdentifiers: [String]
    public let fields: [ProviderSettingsField]

    public init(providerIdentifiers: [String], fields: [ProviderSettingsField]) {
        self.providerIdentifiers = providerIdentifiers
        self.fields = fields
    }

    /// Fields currently visible given `values`, i.e. `visibleWhen` unset or satisfied — mirrors
    /// the web form only rendering conditional fields once their trigger field matches.
    public func visibleFields(for values: [String: String]) -> [ProviderSettingsField] {
        fields.filter { isVisible($0, in: values) }
    }

    private func isVisible(_ field: ProviderSettingsField, in values: [String: String]) -> Bool {
        guard let condition = field.visibleWhen else { return true }
        return values[condition.key] == condition.value
    }

    /// Validates `values` (raw string form input, keyed by `ProviderSettingsField.key`) against
    /// this schema: required fields present, text length caps, numeric ranges, and single-select
    /// membership. Mirrors the `class-validator` decorators on the corresponding DTO.
    public func validate(_ values: [String: String]) -> [ProviderSettingsValidationError] {
        var errors: [ProviderSettingsValidationError] = []
        for field in visibleFields(for: values) {
            let raw = values[field.key]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if field.isRequired && raw.isEmpty {
                errors.append(.missingRequiredField(key: field.key))
                continue
            }
            guard !raw.isEmpty else { continue }
            switch field.kind {
            case .text(let maxLength), .multilineText(let maxLength):
                if let maxLength, raw.count > maxLength {
                    errors.append(.tooLong(key: field.key, limit: maxLength))
                }
            case .url:
                if URL(string: raw) == nil || !(raw.hasPrefix("http://") || raw.hasPrefix("https://")) {
                    errors.append(.invalidURL(key: field.key))
                }
            case .number(let min, let max):
                guard let number = Double(raw) else {
                    errors.append(.invalidNumber(key: field.key))
                    continue
                }
                if let min, number < min {
                    errors.append(.outOfRange(key: field.key, min: min, max: max))
                } else if let max, number > max {
                    errors.append(.outOfRange(key: field.key, min: min, max: max))
                }
            case .toggle:
                break
            case .singleSelect(let options):
                if !options.contains(where: { $0.value == raw }) {
                    errors.append(.invalidSelection(key: field.key))
                }
            }
        }
        return errors
    }
}

/// A `ProviderSettingsSchema.validate` failure, mirrors a `class-validator` rejection for one
/// field.
public enum ProviderSettingsValidationError: Sendable, Equatable {
    case missingRequiredField(key: String)
    case tooLong(key: String, limit: Int)
    case invalidURL(key: String)
    case invalidNumber(key: String)
    case outOfRange(key: String, min: Double?, max: Double?)
    case invalidSelection(key: String)
}

/// Looks up the settings schema for a channel's provider identifier across every registered
/// catalog (`ProviderSettingsCatalogA` now, `ProviderSettingsCatalogB` once T121 lands).
public enum ProviderSettingsCatalog {
    /// All registered schemas across every batch. Add a new batch's `.schemas` here when it
    /// lands — this is the one place that needs to know the batch files exist.
    public static var all: [ProviderSettingsSchema] {
        ProviderSettingsCatalogA.schemas + ProviderSettingsCatalogB.schemas
    }

    /// The schema for `providerIdentifier` (e.g. `"facebook"`), or `nil` if unregistered.
    public static func schema(for providerIdentifier: String) -> ProviderSettingsSchema? {
        all.first { $0.providerIdentifiers.contains(providerIdentifier) }
    }
}
