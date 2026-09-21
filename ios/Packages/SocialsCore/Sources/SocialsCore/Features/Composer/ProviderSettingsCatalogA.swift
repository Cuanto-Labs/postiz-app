import Foundation

/// Batch A of the per-provider settings schemas: x, linkedin/linkedin-page, facebook,
/// instagram/instagram-standalone, threads, bluesky, mastodon, pinterest. Field lists mirror
/// `libraries/nestjs-libraries/src/dtos/posts/providers-settings/*.dto.ts` exactly (field keys,
/// `@IsIn` option lists, `@MaxLength`/`@MinLength`, `@ValidateIf` conditionals for the fields that
/// support one). Deeply nested repeatable sub-forms that the DTOs allow (X's `article_cover`
/// media, Instagram's `collaborators`/`audio`) are out of scope for this schema engine — the
/// mobile composer doesn't yet support media/nested-object entry, only the scalar per-post
/// settings fields do. `who_can_reply_post`'s `@ValidateIf(post_type !== 'article')` is a negated
/// condition the engine's `visibleWhen` (equality-only) can't express, so it's modeled as
/// optional rather than conditionally required.
public enum ProviderSettingsCatalogA {
    public static let schemas: [ProviderSettingsSchema] = [
        xSchema, linkedinSchema, facebookSchema, instagramSchema, threadsSchema,
        blueskySchema, mastodonSchema, pinterestSchema,
    ]

    /// x.dto.ts — `XDto`.
    public static let xSchema = ProviderSettingsSchema(
        providerIdentifiers: ["x"],
        fields: [
            ProviderSettingsField(
                key: "community", label: "Community URL", kind: .url,
                helpText: "e.g. https://x.com/i/communities/1493446837214187523"),
            ProviderSettingsField(
                key: "who_can_reply_post", label: "Who can reply",
                kind: .singleSelect(options: [
                    ProviderSettingsOption(value: "everyone", label: "Everyone"),
                    ProviderSettingsOption(value: "following", label: "Accounts you follow"),
                    ProviderSettingsOption(value: "mentionedUsers", label: "Mentioned accounts"),
                    ProviderSettingsOption(value: "subscribers", label: "Subscribers"),
                    ProviderSettingsOption(value: "verified", label: "Verified accounts"),
                ])),
            ProviderSettingsField(
                key: "post_type", label: "Post type",
                kind: .singleSelect(options: [
                    ProviderSettingsOption(value: "post", label: "Post"),
                    ProviderSettingsOption(value: "article", label: "Article"),
                ])),
            ProviderSettingsField(
                key: "article_title", label: "Article title", kind: .text(maxLength: nil),
                isRequired: true, visibleWhen: ProviderSettingsCondition(key: "post_type", value: "article")),
            ProviderSettingsField(
                key: "article_status", label: "Article status",
                kind: .singleSelect(options: [
                    ProviderSettingsOption(value: "draft", label: "Draft"),
                    ProviderSettingsOption(value: "published", label: "Published"),
                ]), isRequired: true,
                visibleWhen: ProviderSettingsCondition(key: "post_type", value: "article")),
            ProviderSettingsField(key: "made_with_ai", label: "Made with AI", kind: .toggle),
            ProviderSettingsField(key: "paid_partnership", label: "Paid partnership", kind: .toggle),
        ])

    /// linkedin.dto.ts — `LinkedinDto`, shared by `linkedin` and `linkedin-page`.
    public static let linkedinSchema = ProviderSettingsSchema(
        providerIdentifiers: ["linkedin", "linkedin-page"],
        fields: [
            ProviderSettingsField(
                key: "post_as_images_carousel", label: "Post as image carousel", kind: .toggle),
            ProviderSettingsField(
                key: "carousel_name", label: "Carousel name", kind: .text(maxLength: nil),
                visibleWhen: ProviderSettingsCondition(key: "post_as_images_carousel", value: "true")),
        ])

    /// facebook.dto.ts — `FacebookDto`. `text_format_preset_id` mirrors `FACEBOOK_PRESETS`
    /// (background-color presets for text-only posts).
    public static let facebookSchema = ProviderSettingsSchema(
        providerIdentifiers: ["facebook"],
        fields: [
            ProviderSettingsField(key: "url", label: "Link URL", kind: .url),
            ProviderSettingsField(
                key: "post_type", label: "Post type",
                kind: .singleSelect(options: [
                    ProviderSettingsOption(value: "post", label: "Post"),
                    ProviderSettingsOption(value: "story", label: "Story"),
                ])),
            ProviderSettingsField(
                key: "text_format_preset_id", label: "Background style",
                kind: .singleSelect(options: FacebookPresets.options),
                visibleWhen: ProviderSettingsCondition(key: "post_type", value: "post")),
        ])

    /// instagram.dto.ts — `InstagramDto`, shared by `instagram` and `instagram-standalone`.
    public static let instagramSchema = ProviderSettingsSchema(
        providerIdentifiers: ["instagram", "instagram-standalone"],
        fields: [
            ProviderSettingsField(
                key: "post_type", label: "Post type",
                kind: .singleSelect(options: [
                    ProviderSettingsOption(value: "post", label: "Post"),
                    ProviderSettingsOption(value: "story", label: "Story"),
                ]), isRequired: true),
            ProviderSettingsField(key: "is_trial_reel", label: "Trial reel", kind: .toggle),
            ProviderSettingsField(
                key: "graduation_strategy", label: "Graduation strategy",
                kind: .singleSelect(options: [
                    ProviderSettingsOption(value: "MANUAL", label: "Manual"),
                    ProviderSettingsOption(value: "SS_PERFORMANCE", label: "Performance"),
                ])),
        ])

    /// all.providers.settings.ts maps `threads` to `None` — no extra fields beyond post content.
    public static let threadsSchema = ProviderSettingsSchema(providerIdentifiers: ["threads"], fields: [])

    /// all.providers.settings.ts maps `bluesky` to `None` — no extra fields beyond post content.
    public static let blueskySchema = ProviderSettingsSchema(providerIdentifiers: ["bluesky"], fields: [])

    /// all.providers.settings.ts maps `mastodon` to `None` — no extra fields beyond post content.
    public static let mastodonSchema = ProviderSettingsSchema(providerIdentifiers: ["mastodon"], fields: [])

    /// pinterest.dto.ts — `PinterestSettingsDto`. `board` is the only required field.
    public static let pinterestSchema = ProviderSettingsSchema(
        providerIdentifiers: ["pinterest"],
        fields: [
            ProviderSettingsField(key: "board", label: "Board", kind: .text(maxLength: nil), isRequired: true),
            ProviderSettingsField(key: "title", label: "Title", kind: .text(maxLength: 100)),
            ProviderSettingsField(key: "link", label: "Destination link", kind: .url),
            ProviderSettingsField(key: "dominant_color", label: "Dominant color", kind: .text(maxLength: nil)),
        ])
}

/// Facebook's text-post background-style presets, mirrors `FACEBOOK_PRESETS` in
/// `libraries/nestjs-libraries/src/dtos/posts/providers-settings/facebook.dto.ts` (real preset
/// ids/names from the web app, not sample data). Kept in its own type since it's a large static
/// list, not schema plumbing.
public enum FacebookPresets {
    public static let options: [ProviderSettingsOption] = presets.map {
        ProviderSettingsOption(value: $0.0, label: $0.1)
    }

    /// `(id, name)` pairs copied verbatim from `FACEBOOK_PRESETS` in `facebook.dto.ts`.
    private static let presets: [(String, String)] = [
        ("106018623298955", "Solid purple"),
        ("365653833956649", "Pink tropical plants"),
        ("618093735238824", "Brown illustration"),
        ("191761991491375", "3D hearts"),
        ("2193627793985415", "3D heart-eyes emojis"),
        ("200521337465306", "3D flame emojis"),
        ("1821844087883360", "Walking yellow illustration"),
        ("177465482945164", "Light purple 3D cube pattern"),
        ("160419724814650", "Orange with pink illustration"),
        ("248623902401250", "3D smiling emoji"),
        ("240401816771706", "3D rose emojis"),
        ("1868855943417360", "3D crying-laughter emoji"),
        ("255989551804163", "Eye pink illustration"),
        ("1792915444087912", "Illustration"),
        ("1654916007940525", "Light grey illustration"),
        ("1679248482160767", "Light blue illustration"),
        ("518948401838663", "Pink heart pattern on pink"),
        ("423339708139719", "Illustration"),
        ("204187940028597", "Solid red"),
        ("621731364695726", "Solid red"),
        ("518596398537417", "Red illustration"),
        ("134273813910336", "Tree red illustration"),
        ("217321755510854", "Pink and purple hearts on pink"),
        ("323371698179784", "Sunset red illustration"),
        ("901751159967576", "Gradient, dark orange-red"),
        ("552118025129095", "Brown illustration"),
        ("263789377694911", "Apple red illustration"),
        ("606643333067842", "Tulip light-orange illustration"),
        ("458988134561491", "Cat dark-orange illustration"),
        ("548109108916650", "Unicorn red illustration"),
        ("175493843120364", "Pink and yellow gradient"),
        ("338976169966519", "Stairs beige illustration"),
        ("206513879997925", "Spiral beige illustration"),
        ("168373304017982", "Cube beige illustration"),
        ("1271157196337260", "Solid red"),
        ("174496469882866", "Lemon yellow illustration"),
        ("862667370603267", "Egg light-yellow illustration"),
        ("127541261450947", "Ball green illustration"),
        ("218067308976029", "Light grey illustration"),
        ("688479024672716", "Gradient, teal light-green"),
        ("238863426886624", "Cat light-blue illustration"),
        ("301029513638534", "Solid teal"),
        ("154977255088164", "Solid teal"),
        ("1941912679424590", "Gradient, grey dark-grey"),
        ("396343990807392", "Flower teal illustration"),
        ("143093446467972", "Blue clouds on dark blue"),
        ("161409924510923", "Rocket ship makes heart in sky"),
        ("145893972683590", "Solid dark purple"),
        ("217761075370932", "Solid blue"),
        ("931584293685988", "Wave blue illustration"),
        ("148862695775447", "Pink and purple hearts on purple"),
        ("100114277230063", "Deep sea blue illustration"),
        ("558836317844129", "Spiral purple illustration"),
        ("172497526576609", "Watermelon light-purple illustration"),
        ("433967226963128", "Solid purple"),
        ("197865920864520", "Donut light-purple illustration"),
        ("643122496026756", "Pink illustration"),
        ("762009070855346", "Balloon light-grey illustration"),
        ("228164237768720", "Grey heart pattern on black"),
        ("146487026137131", "Rain black illustration"),
        ("221828835275596", "Glasses light-grey illustration"),
        ("1903718606535395", "Solid red"),
        ("1881421442117417", "Solid black"),
        ("249307305544279", "Gradient, red-blue"),
        ("1777259169190672", "Gradient, purple-magenta"),
        ("303063890126415", "Yellow/orange/pink gradient"),
        ("122708641613922", "Gradient, dark-grey-black"),
        ("319468561816672", "Dark blue illustration"),
        ("121945541697934", "Pink illustration"),
        ("288211338285858", "Blue illustration"),
        ("446330032368780", "Gradient, red"),
        ("219266485227663", "Solid magenta"),
        ("1289741387813798", "Solid dark red"),
        ("1365883126823705", "Solid blue"),
    ]
}
