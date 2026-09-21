import Foundation

/// Batch B of the per-provider settings schemas: tiktok, youtube, reddit, discord, slack,
/// telegram, medium, devto, hashnode, wordpress, lemmy, dribbble, gmb, wrapcast (Farcaster —
/// the card calls this "warpcast", but the real provider identifier in
/// `farcaster.provider.ts`/`all.providers.settings.ts` is the typo'd `"wrapcast"`), nostr, vk,
/// kick, twitch, tumblr, mewe, skool, whop, listmonk, moltbook. Field lists mirror
/// `libraries/nestjs-libraries/src/dtos/posts/providers-settings/*.dto.ts` exactly, same
/// conventions as `ProviderSettingsCatalogA`. Fields this engine can't express are left out
/// rather than faked:
/// - Repeatable/array sub-forms (Reddit's/Lemmy's array-of-subreddits, Farcaster's
///   array-of-channels, Medium/DevTo/Hashnode's tags arrays, WordPress's category/tag id
///   arrays, YouTube's `tags`) — no array field kind exists yet. For Reddit and Lemmy, which
///   wrap a single flat object per array entry, the inner object's scalar fields are modeled
///   directly (as if posting to one subreddit/community); the outer repeatable-array part and
///   any nested object inside it (Reddit's `flair`) are out of scope.
/// - Nested media objects (DevTo/Hashnode/WordPress `main_image`) — out of scope, same as
///   Catalog A's nested-media exclusions.
/// - `MinLength` is not modeled — the engine's `.text`/`.multilineText` kinds only support a
///   max length cap, no minimum.
/// - TikTok's many boolean/select fields read as conditionally-applicable in the DTO's own
///   comments, but those comments are documentation only (not enforced `@ValidateIf`s), so no
///   synthetic `visibleWhen` is added for them.
public enum ProviderSettingsCatalogB {
    public static let schemas: [ProviderSettingsSchema] = [
        tiktokSchema, youtubeSchema, redditSchema, discordSchema, slackSchema, telegramSchema,
        mediumSchema, devtoSchema, hashnodeSchema, wordpressSchema, lemmySchema, dribbbleSchema,
        gmbSchema, wrapcastSchema, nostrSchema, vkSchema, kickSchema, twitchSchema, tumblrSchema,
        meweSchema, skoolSchema, whopSchema, listmonkSchema, moltbookSchema,
    ]

    /// tiktok.dto.ts — `TikTokDto`. `music`/`location` (nested objects) are out of scope.
    public static let tiktokSchema = ProviderSettingsSchema(
        providerIdentifiers: ["tiktok"],
        fields: [
            ProviderSettingsField(key: "title", label: "Title", kind: .text(maxLength: 90)),
            ProviderSettingsField(
                key: "privacy_level", label: "Privacy",
                kind: .singleSelect(options: [
                    ProviderSettingsOption(value: "PUBLIC_TO_EVERYONE", label: "Public"),
                    ProviderSettingsOption(value: "MUTUAL_FOLLOW_FRIENDS", label: "Friends"),
                    ProviderSettingsOption(value: "FOLLOWER_OF_CREATOR", label: "Followers"),
                    ProviderSettingsOption(value: "SELF_ONLY", label: "Only me"),
                ]), isRequired: true),
            ProviderSettingsField(key: "duet", label: "Allow duet", kind: .toggle),
            ProviderSettingsField(key: "stitch", label: "Allow stitch", kind: .toggle),
            ProviderSettingsField(key: "comment", label: "Allow comments", kind: .toggle),
            ProviderSettingsField(
                key: "autoAddMusic", label: "Auto add music",
                kind: .singleSelect(options: [
                    ProviderSettingsOption(value: "yes", label: "Yes"),
                    ProviderSettingsOption(value: "no", label: "No"),
                ]), isRequired: true),
            ProviderSettingsField(
                key: "brand_content_toggle", label: "Branded content", kind: .toggle),
            ProviderSettingsField(key: "video_made_with_ai", label: "Made with AI", kind: .toggle),
            ProviderSettingsField(
                key: "brand_organic_toggle", label: "Promotional content", kind: .toggle),
            ProviderSettingsField(
                key: "content_posting_method", label: "Posting method",
                kind: .singleSelect(options: [
                    ProviderSettingsOption(value: "DIRECT_POST", label: "Direct post"),
                    ProviderSettingsOption(value: "UPLOAD", label: "Upload to inbox"),
                ]), isRequired: true),
        ])

    /// youtube.settings.dto.ts — `YoutubeSettingsDto`. `thumbnail` (nested media) and `tags`
    /// (array) are out of scope.
    public static let youtubeSchema = ProviderSettingsSchema(
        providerIdentifiers: ["youtube"],
        fields: [
            ProviderSettingsField(
                key: "title", label: "Title", kind: .text(maxLength: 100), isRequired: true),
            ProviderSettingsField(
                key: "type", label: "Visibility",
                kind: .singleSelect(options: [
                    ProviderSettingsOption(value: "public", label: "Public"),
                    ProviderSettingsOption(value: "private", label: "Private"),
                    ProviderSettingsOption(value: "unlisted", label: "Unlisted"),
                ]), isRequired: true),
            ProviderSettingsField(
                key: "selfDeclaredMadeForKids", label: "Made for kids",
                kind: .singleSelect(options: [
                    ProviderSettingsOption(value: "yes", label: "Yes"),
                    ProviderSettingsOption(value: "no", label: "No"),
                ])),
        ])

    /// reddit.dto.ts — `RedditSettingsDto` wraps `subreddit: RedditSettingsValueDto[]`
    /// (post-to-multiple-subreddits). Modeled here as the single inner object's fields (posting
    /// to one subreddit); the outer array and the nested `flair` object are out of scope.
    public static let redditSchema = ProviderSettingsSchema(
        providerIdentifiers: ["reddit"],
        fields: [
            ProviderSettingsField(
                key: "subreddit", label: "Subreddit", kind: .text(maxLength: nil),
                isRequired: true, helpText: "Must start with /r"),
            ProviderSettingsField(
                key: "title", label: "Title", kind: .text(maxLength: nil), isRequired: true),
            ProviderSettingsField(
                key: "type", label: "Post type",
                kind: .singleSelect(options: [
                    ProviderSettingsOption(value: "self", label: "Text post"),
                    ProviderSettingsOption(value: "link", label: "Link post"),
                    ProviderSettingsOption(value: "media", label: "Media post"),
                ]), isRequired: true),
            ProviderSettingsField(
                key: "url", label: "Link URL", kind: .url,
                visibleWhen: ProviderSettingsCondition(key: "type", value: "link")),
            ProviderSettingsField(
                key: "is_flair_required", label: "Flair required", kind: .toggle),
        ])

    /// discord.dto.ts — `DiscordDto`.
    public static let discordSchema = ProviderSettingsSchema(
        providerIdentifiers: ["discord"],
        fields: [
            ProviderSettingsField(
                key: "channel", label: "Channel", kind: .text(maxLength: nil), isRequired: true,
                helpText: "Channel must be an id"),
        ])

    /// slack.dto.ts — `SlackDto`.
    public static let slackSchema = ProviderSettingsSchema(
        providerIdentifiers: ["slack"],
        fields: [
            ProviderSettingsField(
                key: "channel", label: "Channel", kind: .text(maxLength: nil), isRequired: true,
                helpText: "Channel must be an id"),
        ])

    /// all.providers.settings.ts maps `telegram` to `setEmpty` — no extra fields.
    public static let telegramSchema = ProviderSettingsSchema(
        providerIdentifiers: ["telegram"], fields: [])

    /// medium.settings.dto.ts — `MediumSettingsDto`. `tags` (array) is out of scope.
    public static let mediumSchema = ProviderSettingsSchema(
        providerIdentifiers: ["medium"],
        fields: [
            ProviderSettingsField(
                key: "title", label: "Title", kind: .text(maxLength: nil), isRequired: true),
            ProviderSettingsField(
                key: "subtitle", label: "Subtitle", kind: .text(maxLength: nil), isRequired: true),
            ProviderSettingsField(key: "canonical", label: "Canonical URL", kind: .url),
            ProviderSettingsField(
                key: "publication", label: "Publication", kind: .text(maxLength: nil)),
        ])

    /// dev.to.settings.dto.ts — `DevToSettingsDto`. `main_image` (nested media) and `tags`
    /// (array) are out of scope.
    public static let devtoSchema = ProviderSettingsSchema(
        providerIdentifiers: ["devto"],
        fields: [
            ProviderSettingsField(
                key: "title", label: "Title", kind: .text(maxLength: nil), isRequired: true),
            ProviderSettingsField(key: "canonical", label: "Canonical URL", kind: .url),
            ProviderSettingsField(
                key: "organization", label: "Organization", kind: .text(maxLength: nil)),
        ])

    /// hashnode.settings.dto.ts — `HashnodeSettingsDto`. `main_image` (nested media) and `tags`
    /// (array, required with min size 1 in the DTO) are out of scope.
    public static let hashnodeSchema = ProviderSettingsSchema(
        providerIdentifiers: ["hashnode"],
        fields: [
            ProviderSettingsField(
                key: "title", label: "Title", kind: .text(maxLength: nil), isRequired: true),
            ProviderSettingsField(
                key: "subtitle", label: "Subtitle", kind: .text(maxLength: nil)),
            ProviderSettingsField(key: "canonical", label: "Canonical URL", kind: .url),
            ProviderSettingsField(
                key: "publication", label: "Publication", kind: .text(maxLength: nil),
                isRequired: true),
        ])

    /// wordpress.dto.ts — `WordpressDto`. `main_image` (nested media) and `categories`/`tags`
    /// (id arrays) are out of scope.
    public static let wordpressSchema = ProviderSettingsSchema(
        providerIdentifiers: ["wordpress"],
        fields: [
            ProviderSettingsField(
                key: "title", label: "Title", kind: .text(maxLength: nil), isRequired: true),
            ProviderSettingsField(
                key: "type", label: "Post type", kind: .text(maxLength: nil), isRequired: true),
            ProviderSettingsField(
                key: "status", label: "Status",
                kind: .singleSelect(options: [
                    ProviderSettingsOption(value: "publish", label: "Publish"),
                    ProviderSettingsOption(value: "draft", label: "Draft"),
                    ProviderSettingsOption(value: "pending", label: "Pending"),
                    ProviderSettingsOption(value: "private", label: "Private"),
                ])),
        ])

    /// lemmy.dto.ts — `LemmySettingsDto` wraps `subreddit: LemmySettingsValueDto[]`
    /// (post-to-multiple-communities), same shape as Reddit. Modeled as the single inner
    /// object's fields; the outer array is out of scope.
    public static let lemmySchema = ProviderSettingsSchema(
        providerIdentifiers: ["lemmy"],
        fields: [
            ProviderSettingsField(
                key: "subreddit", label: "Community", kind: .text(maxLength: nil),
                isRequired: true),
            ProviderSettingsField(
                key: "id", label: "Instance", kind: .text(maxLength: nil), isRequired: true),
            ProviderSettingsField(
                key: "title", label: "Title", kind: .text(maxLength: nil), isRequired: true),
            ProviderSettingsField(key: "url", label: "URL", kind: .url),
        ])

    /// dribbble.dto.ts — `DribbbleDto`.
    public static let dribbbleSchema = ProviderSettingsSchema(
        providerIdentifiers: ["dribbble"],
        fields: [
            ProviderSettingsField(
                key: "title", label: "Title", kind: .text(maxLength: nil), isRequired: true,
                helpText: "Title is required"),
            ProviderSettingsField(key: "team", label: "Team URL", kind: .url),
        ])

    /// gmb.settings.dto.ts — `GmbSettingsDto` (Google Business Profile).
    public static let gmbSchema = ProviderSettingsSchema(
        providerIdentifiers: ["gmb"],
        fields: [
            ProviderSettingsField(
                key: "topicType", label: "Post type",
                kind: .singleSelect(options: [
                    ProviderSettingsOption(value: "STANDARD", label: "Standard"),
                    ProviderSettingsOption(value: "EVENT", label: "Event"),
                    ProviderSettingsOption(value: "OFFER", label: "Offer"),
                ])),
            ProviderSettingsField(
                key: "callToActionType", label: "Call to action",
                kind: .singleSelect(options: [
                    ProviderSettingsOption(value: "NONE", label: "None"),
                    ProviderSettingsOption(value: "BOOK", label: "Book"),
                    ProviderSettingsOption(value: "ORDER", label: "Order"),
                    ProviderSettingsOption(value: "SHOP", label: "Shop"),
                    ProviderSettingsOption(value: "LEARN_MORE", label: "Learn more"),
                    ProviderSettingsOption(value: "SIGN_UP", label: "Sign up"),
                    ProviderSettingsOption(value: "GET_OFFER", label: "Get offer"),
                    ProviderSettingsOption(value: "CALL", label: "Call"),
                ])),
            ProviderSettingsField(key: "callToActionUrl", label: "Call to action URL", kind: .url),
            ProviderSettingsField(
                key: "eventTitle", label: "Event title", kind: .text(maxLength: nil),
                visibleWhen: ProviderSettingsCondition(key: "topicType", value: "EVENT")),
            ProviderSettingsField(
                key: "eventStartDate", label: "Event start date", kind: .text(maxLength: nil)),
            ProviderSettingsField(
                key: "eventEndDate", label: "Event end date", kind: .text(maxLength: nil)),
            ProviderSettingsField(
                key: "eventStartTime", label: "Event start time", kind: .text(maxLength: nil)),
            ProviderSettingsField(
                key: "eventEndTime", label: "Event end time", kind: .text(maxLength: nil)),
            ProviderSettingsField(
                key: "offerCouponCode", label: "Coupon code", kind: .text(maxLength: nil)),
            ProviderSettingsField(key: "offerRedeemUrl", label: "Redeem URL", kind: .url),
            ProviderSettingsField(
                key: "offerTerms", label: "Offer terms", kind: .multilineText(maxLength: nil)),
        ])

    /// farcaster.dto.ts — `FarcasterDto`. Real provider identifier is `"wrapcast"` (a typo in
    /// `farcaster.provider.ts`, not `"warpcast"`). The DTO's `subreddit` field is an
    /// array-of-channel-picks (`FarcasterValue[]`, each `{ value: { id } }`) — no scalar fields
    /// exist to model with this engine's field kinds, so this schema is intentionally empty,
    /// same treatment as the other no-extra-fields providers.
    public static let wrapcastSchema = ProviderSettingsSchema(
        providerIdentifiers: ["wrapcast"], fields: [])

    /// all.providers.settings.ts maps `nostr` to `setEmpty` — no extra fields.
    public static let nostrSchema = ProviderSettingsSchema(providerIdentifiers: ["nostr"], fields: [])

    /// all.providers.settings.ts maps `vk` to `setEmpty` — no extra fields.
    public static let vkSchema = ProviderSettingsSchema(providerIdentifiers: ["vk"], fields: [])

    /// kick.dto.ts — `KickDto` has no fields.
    public static let kickSchema = ProviderSettingsSchema(providerIdentifiers: ["kick"], fields: [])

    /// twitch.dto.ts — `TwitchDto`.
    public static let twitchSchema = ProviderSettingsSchema(
        providerIdentifiers: ["twitch"],
        fields: [
            ProviderSettingsField(
                key: "messageType", label: "Message type",
                kind: .singleSelect(options: [
                    ProviderSettingsOption(value: "message", label: "Message"),
                    ProviderSettingsOption(value: "announcement", label: "Announcement"),
                ])),
            ProviderSettingsField(
                key: "announcementColor", label: "Announcement color",
                kind: .singleSelect(options: [
                    ProviderSettingsOption(value: "primary", label: "Primary"),
                    ProviderSettingsOption(value: "blue", label: "Blue"),
                    ProviderSettingsOption(value: "green", label: "Green"),
                    ProviderSettingsOption(value: "orange", label: "Orange"),
                    ProviderSettingsOption(value: "purple", label: "Purple"),
                ]),
                visibleWhen: ProviderSettingsCondition(key: "messageType", value: "announcement")),
        ])

    /// tumblr.dto.ts — `TumblrDto`.
    public static let tumblrSchema = ProviderSettingsSchema(
        providerIdentifiers: ["tumblr"],
        fields: [
            ProviderSettingsField(key: "title", label: "Title", kind: .text(maxLength: 4096)),
            ProviderSettingsField(key: "link", label: "Link URL", kind: .url),
            ProviderSettingsField(key: "sourceUrl", label: "Source URL", kind: .url),
            ProviderSettingsField(key: "tags", label: "Tags", kind: .text(maxLength: 4096)),
        ])

    /// mewe.dto.ts — `MeweDto`.
    public static let meweSchema = ProviderSettingsSchema(
        providerIdentifiers: ["mewe"],
        fields: [
            ProviderSettingsField(
                key: "postType", label: "Post to",
                kind: .singleSelect(options: [
                    ProviderSettingsOption(value: "timeline", label: "Timeline"),
                    ProviderSettingsOption(value: "group", label: "Group"),
                ]), isRequired: true),
            ProviderSettingsField(
                key: "group", label: "Group", kind: .text(maxLength: nil),
                helpText: "Group must be an id",
                visibleWhen: ProviderSettingsCondition(key: "postType", value: "group")),
        ])

    /// skool.dto.ts — `SkoolDto`.
    public static let skoolSchema = ProviderSettingsSchema(
        providerIdentifiers: ["skool"],
        fields: [
            ProviderSettingsField(
                key: "group", label: "Group", kind: .text(maxLength: nil), isRequired: true,
                helpText: "Group must be an id"),
            ProviderSettingsField(
                key: "label", label: "Label", kind: .text(maxLength: nil), isRequired: true,
                helpText: "Label must be an id"),
            ProviderSettingsField(
                key: "title", label: "Title", kind: .text(maxLength: nil), isRequired: true),
        ])

    /// whop.dto.ts — `WhopDto`.
    public static let whopSchema = ProviderSettingsSchema(
        providerIdentifiers: ["whop"],
        fields: [
            ProviderSettingsField(
                key: "company", label: "Company", kind: .text(maxLength: nil), isRequired: true,
                helpText: "Company ID"),
            ProviderSettingsField(
                key: "experience", label: "Experience", kind: .text(maxLength: nil),
                isRequired: true, helpText: "Experience ID for the Whop forum"),
            ProviderSettingsField(key: "title", label: "Title", kind: .text(maxLength: nil)),
        ])

    /// listmonk.dto.ts — `ListmonkDto`.
    public static let listmonkSchema = ProviderSettingsSchema(
        providerIdentifiers: ["listmonk"],
        fields: [
            ProviderSettingsField(
                key: "subject", label: "Subject", kind: .text(maxLength: nil), isRequired: true),
            ProviderSettingsField(
                key: "preview", label: "Preview", kind: .text(maxLength: nil), isRequired: true),
            ProviderSettingsField(
                key: "list", label: "List", kind: .text(maxLength: nil), isRequired: true,
                helpText: "List must be an id"),
            ProviderSettingsField(
                key: "template", label: "Template", kind: .text(maxLength: nil),
                helpText: "Template must be an id"),
        ])

    /// moltbook.dto.ts — `MoltbookDto`.
    public static let moltbookSchema = ProviderSettingsSchema(
        providerIdentifiers: ["moltbook"],
        fields: [
            ProviderSettingsField(
                key: "submolt", label: "Submolt", kind: .text(maxLength: nil), isRequired: true),
        ])
}
