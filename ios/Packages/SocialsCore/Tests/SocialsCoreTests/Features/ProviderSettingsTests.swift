import Testing

@testable import SocialsCore

@Suite("ProviderSettings")
struct ProviderSettingsTests {

    // MARK: - Catalog lookup

    @Test
    func catalogResolvesEachBatchAProvider() {
        let identifiers = [
            "x", "linkedin", "linkedin-page", "facebook", "instagram",
            "instagram-standalone", "threads", "bluesky", "mastodon", "pinterest",
        ]
        for identifier in identifiers {
            #expect(ProviderSettingsCatalog.schema(for: identifier) != nil, "missing schema for \(identifier)")
        }
    }

    @Test
    func catalogReturnsNilForUnknownProvider() {
        #expect(ProviderSettingsCatalog.schema(for: "not-a-real-provider") == nil)
    }

    @Test
    func linkedinAndLinkedinPageShareOneSchema() {
        let linkedin = ProviderSettingsCatalog.schema(for: "linkedin")
        let linkedinPage = ProviderSettingsCatalog.schema(for: "linkedin-page")
        #expect(linkedin == linkedinPage)
    }

    @Test
    func instagramAndStandaloneShareOneSchema() {
        let instagram = ProviderSettingsCatalog.schema(for: "instagram")
        let standalone = ProviderSettingsCatalog.schema(for: "instagram-standalone")
        #expect(instagram == standalone)
    }

    @Test
    func threadsBlueskyMastodonHaveNoExtraFields() {
        #expect(ProviderSettingsCatalog.schema(for: "threads")?.fields.isEmpty == true)
        #expect(ProviderSettingsCatalog.schema(for: "bluesky")?.fields.isEmpty == true)
        #expect(ProviderSettingsCatalog.schema(for: "mastodon")?.fields.isEmpty == true)
    }

    // MARK: - Pinterest (required field + optional caps)

    @Test
    func pinterestRequiresBoard() {
        let schema = ProviderSettingsCatalogA.pinterestSchema
        let errors = schema.validate([:])
        #expect(errors.contains(.missingRequiredField(key: "board")))
    }

    @Test
    func pinterestPassesWithJustBoard() {
        let schema = ProviderSettingsCatalogA.pinterestSchema
        let errors = schema.validate(["board": "My Board"])
        #expect(errors.isEmpty)
    }

    @Test
    func pinterestTitleRespectsMaxLength() {
        let schema = ProviderSettingsCatalogA.pinterestSchema
        let longTitle = String(repeating: "a", count: 101)
        let errors = schema.validate(["board": "My Board", "title": longTitle])
        #expect(errors.contains(.tooLong(key: "title", limit: 100)))
    }

    @Test
    func pinterestLinkMustBeAValidURL() {
        let schema = ProviderSettingsCatalogA.pinterestSchema
        let errors = schema.validate(["board": "My Board", "link": "not-a-url"])
        #expect(errors.contains(.invalidURL(key: "link")))
    }

    // MARK: - X (conditional visibility)

    @Test
    func xArticleTitleHiddenWhenPostTypeIsNotArticle() {
        let schema = ProviderSettingsCatalogA.xSchema
        let visible = schema.visibleFields(for: ["post_type": "post"])
        #expect(!visible.contains { $0.key == "article_title" })
    }

    @Test
    func xArticleTitleRequiredWhenPostTypeIsArticle() {
        let schema = ProviderSettingsCatalogA.xSchema
        let errors = schema.validate(["post_type": "article"])
        #expect(errors.contains(.missingRequiredField(key: "article_title")))
        #expect(errors.contains(.missingRequiredField(key: "article_status")))
    }

    @Test
    func xPassesWithArticleFieldsFilled() {
        let schema = ProviderSettingsCatalogA.xSchema
        let errors = schema.validate([
            "post_type": "article", "article_title": "My Article", "article_status": "draft",
        ])
        #expect(errors.isEmpty)
    }

    @Test
    func xRejectsUnknownWhoCanReplyOption() {
        let schema = ProviderSettingsCatalogA.xSchema
        let errors = schema.validate(["who_can_reply_post": "nobody"])
        #expect(errors.contains(.invalidSelection(key: "who_can_reply_post")))
    }

    // MARK: - Linkedin (toggle-gated visibility)

    @Test
    func linkedinCarouselNameHiddenUntilCarouselToggleOn() {
        let schema = ProviderSettingsCatalogA.linkedinSchema
        let visible = schema.visibleFields(for: [:])
        #expect(!visible.contains { $0.key == "carousel_name" })

        let visibleWhenOn = schema.visibleFields(for: ["post_as_images_carousel": "true"])
        #expect(visibleWhenOn.contains { $0.key == "carousel_name" })
    }

    // MARK: - Facebook (large option set from real preset data)

    @Test
    func facebookPresetPickerIsPopulatedFromRealPresetData() {
        #expect(FacebookPresets.options.count == 74)
        #expect(FacebookPresets.options.first?.value == "106018623298955")
        #expect(FacebookPresets.options.first?.label == "Solid purple")
    }

    @Test
    func facebookRejectsUnknownPresetId() {
        let schema = ProviderSettingsCatalogA.facebookSchema
        let errors = schema.validate(["post_type": "post", "text_format_preset_id": "does-not-exist"])
        #expect(errors.contains(.invalidSelection(key: "text_format_preset_id")))
    }

    @Test
    func facebookAcceptsKnownPresetId() {
        let schema = ProviderSettingsCatalogA.facebookSchema
        let errors = schema.validate(["post_type": "post", "text_format_preset_id": "106018623298955"])
        #expect(errors.isEmpty)
    }

    // MARK: - Instagram (required field)

    @Test
    func instagramRequiresPostType() {
        let schema = ProviderSettingsCatalogA.instagramSchema
        let errors = schema.validate([:])
        #expect(errors.contains(.missingRequiredField(key: "post_type")))
    }

    @Test
    func instagramPassesWithPostType() {
        let schema = ProviderSettingsCatalogA.instagramSchema
        let errors = schema.validate(["post_type": "post"])
        #expect(errors.isEmpty)
    }
}
