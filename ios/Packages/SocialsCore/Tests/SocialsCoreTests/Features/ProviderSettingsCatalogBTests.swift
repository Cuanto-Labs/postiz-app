import Testing

@testable import SocialsCore

@Suite("ProviderSettingsCatalogB")
struct ProviderSettingsCatalogBTests {

    // MARK: - Catalog lookup

    @Test
    func catalogResolvesEachBatchBProvider() {
        let identifiers = [
            "tiktok", "youtube", "reddit", "discord", "slack", "telegram", "medium", "devto",
            "hashnode", "wordpress", "lemmy", "dribbble", "gmb", "wrapcast", "nostr", "vk",
            "kick", "twitch", "tumblr", "mewe", "skool", "whop", "listmonk", "moltbook",
        ]
        for identifier in identifiers {
            #expect(ProviderSettingsCatalog.schema(for: identifier) != nil, "missing schema for \(identifier)")
        }
    }

    @Test
    func telegramNostrVkKickWrapcastHaveNoExtraFields() {
        #expect(ProviderSettingsCatalog.schema(for: "telegram")?.fields.isEmpty == true)
        #expect(ProviderSettingsCatalog.schema(for: "nostr")?.fields.isEmpty == true)
        #expect(ProviderSettingsCatalog.schema(for: "vk")?.fields.isEmpty == true)
        #expect(ProviderSettingsCatalog.schema(for: "kick")?.fields.isEmpty == true)
        #expect(ProviderSettingsCatalog.schema(for: "wrapcast")?.fields.isEmpty == true)
    }

    // MARK: - TikTok (required singleSelect fields)

    @Test
    func tiktokRequiresPrivacyLevelAutoAddMusicAndPostingMethod() {
        let schema = ProviderSettingsCatalogB.tiktokSchema
        let errors = schema.validate([:])
        #expect(errors.contains(.missingRequiredField(key: "privacy_level")))
        #expect(errors.contains(.missingRequiredField(key: "autoAddMusic")))
        #expect(errors.contains(.missingRequiredField(key: "content_posting_method")))
    }

    @Test
    func tiktokTitleRespectsMaxLength() {
        let schema = ProviderSettingsCatalogB.tiktokSchema
        let longTitle = String(repeating: "a", count: 91)
        let errors = schema.validate([
            "title": longTitle, "privacy_level": "PUBLIC_TO_EVERYONE", "autoAddMusic": "yes",
            "content_posting_method": "DIRECT_POST",
        ])
        #expect(errors.contains(.tooLong(key: "title", limit: 90)))
    }

    // MARK: - YouTube (required fields + maxLength)

    @Test
    func youtubeRequiresTitleAndType() {
        let schema = ProviderSettingsCatalogB.youtubeSchema
        let errors = schema.validate([:])
        #expect(errors.contains(.missingRequiredField(key: "title")))
        #expect(errors.contains(.missingRequiredField(key: "type")))
    }

    @Test
    func youtubePassesWithTitleAndType() {
        let schema = ProviderSettingsCatalogB.youtubeSchema
        let errors = schema.validate(["title": "My Video", "type": "public"])
        #expect(errors.isEmpty)
    }

    // MARK: - Reddit (flattened single-subreddit shape)

    @Test
    func redditRequiresSubredditTitleAndType() {
        let schema = ProviderSettingsCatalogB.redditSchema
        let errors = schema.validate([:])
        #expect(errors.contains(.missingRequiredField(key: "subreddit")))
        #expect(errors.contains(.missingRequiredField(key: "title")))
        #expect(errors.contains(.missingRequiredField(key: "type")))
    }

    @Test
    func redditLinkUrlHiddenUnlessTypeIsLink() {
        let schema = ProviderSettingsCatalogB.redditSchema
        let visible = schema.visibleFields(for: ["type": "self"])
        #expect(!visible.contains { $0.key == "url" })

        let visibleWhenLink = schema.visibleFields(for: ["type": "link"])
        #expect(visibleWhenLink.contains { $0.key == "url" })
    }

    // MARK: - Lemmy (flattened single-community shape)

    @Test
    func lemmyRequiresSubredditIdAndTitle() {
        let schema = ProviderSettingsCatalogB.lemmySchema
        let errors = schema.validate([:])
        #expect(errors.contains(.missingRequiredField(key: "subreddit")))
        #expect(errors.contains(.missingRequiredField(key: "id")))
        #expect(errors.contains(.missingRequiredField(key: "title")))
    }

    @Test
    func lemmyUrlMustBeValidWhenPresent() {
        let schema = ProviderSettingsCatalogB.lemmySchema
        let errors = schema.validate([
            "subreddit": "test", "id": "instance.example", "title": "Hi", "url": "not-a-url",
        ])
        #expect(errors.contains(.invalidURL(key: "url")))
    }

    // MARK: - Discord / Slack (single required id field)

    @Test
    func discordRequiresChannel() {
        let schema = ProviderSettingsCatalogB.discordSchema
        let errors = schema.validate([:])
        #expect(errors.contains(.missingRequiredField(key: "channel")))
    }

    @Test
    func slackRequiresChannel() {
        let schema = ProviderSettingsCatalogB.slackSchema
        let errors = schema.validate([:])
        #expect(errors.contains(.missingRequiredField(key: "channel")))
    }

    // MARK: - Medium / DevTo / Hashnode (required text + optional canonical URL)

    @Test
    func mediumRequiresTitleAndSubtitle() {
        let schema = ProviderSettingsCatalogB.mediumSchema
        let errors = schema.validate([:])
        #expect(errors.contains(.missingRequiredField(key: "title")))
        #expect(errors.contains(.missingRequiredField(key: "subtitle")))
    }

    @Test
    func mediumCanonicalMustBeValidURL() {
        let schema = ProviderSettingsCatalogB.mediumSchema
        let errors = schema.validate([
            "title": "T", "subtitle": "S", "canonical": "not-a-url",
        ])
        #expect(errors.contains(.invalidURL(key: "canonical")))
    }

    @Test
    func devtoRequiresTitle() {
        let schema = ProviderSettingsCatalogB.devtoSchema
        let errors = schema.validate([:])
        #expect(errors.contains(.missingRequiredField(key: "title")))
    }

    @Test
    func hashnodeRequiresTitleAndPublication() {
        let schema = ProviderSettingsCatalogB.hashnodeSchema
        let errors = schema.validate([:])
        #expect(errors.contains(.missingRequiredField(key: "title")))
        #expect(errors.contains(.missingRequiredField(key: "publication")))
        #expect(!errors.contains(.missingRequiredField(key: "subtitle")))
    }

    // MARK: - WordPress (required + optional singleSelect status)

    @Test
    func wordpressRequiresTitleAndType() {
        let schema = ProviderSettingsCatalogB.wordpressSchema
        let errors = schema.validate([:])
        #expect(errors.contains(.missingRequiredField(key: "title")))
        #expect(errors.contains(.missingRequiredField(key: "type")))
    }

    @Test
    func wordpressRejectsUnknownStatus() {
        let schema = ProviderSettingsCatalogB.wordpressSchema
        let errors = schema.validate(["title": "T", "type": "post", "status": "archived"])
        #expect(errors.contains(.invalidSelection(key: "status")))
    }

    @Test
    func wordpressAcceptsKnownStatus() {
        let schema = ProviderSettingsCatalogB.wordpressSchema
        let errors = schema.validate(["title": "T", "type": "post", "status": "draft"])
        #expect(errors.isEmpty)
    }

    // MARK: - Dribbble (required title + optional team URL)

    @Test
    func dribbbleRequiresTitle() {
        let schema = ProviderSettingsCatalogB.dribbbleSchema
        let errors = schema.validate([:])
        #expect(errors.contains(.missingRequiredField(key: "title")))
    }

    @Test
    func dribbbleTeamMustBeValidURL() {
        let schema = ProviderSettingsCatalogB.dribbbleSchema
        let errors = schema.validate(["title": "T", "team": "not-a-url"])
        #expect(errors.contains(.invalidURL(key: "team")))
    }

    // MARK: - GMB (conditional visibility)

    @Test
    func gmbEventTitleHiddenUnlessTopicTypeIsEvent() {
        let schema = ProviderSettingsCatalogB.gmbSchema
        let visible = schema.visibleFields(for: ["topicType": "STANDARD"])
        #expect(!visible.contains { $0.key == "eventTitle" })

        let visibleWhenEvent = schema.visibleFields(for: ["topicType": "EVENT"])
        #expect(visibleWhenEvent.contains { $0.key == "eventTitle" })
    }

    @Test
    func gmbAllFieldsOptionalWithNoValues() {
        let schema = ProviderSettingsCatalogB.gmbSchema
        let errors = schema.validate([:])
        #expect(errors.isEmpty)
    }

    // MARK: - Twitch (conditional visibility)

    @Test
    func twitchAnnouncementColorHiddenUnlessMessageTypeIsAnnouncement() {
        let schema = ProviderSettingsCatalogB.twitchSchema
        let visible = schema.visibleFields(for: ["messageType": "message"])
        #expect(!visible.contains { $0.key == "announcementColor" })

        let visibleWhenAnnouncement = schema.visibleFields(for: ["messageType": "announcement"])
        #expect(visibleWhenAnnouncement.contains { $0.key == "announcementColor" })
    }

    // MARK: - Tumblr (optional maxLength + URL fields)

    @Test
    func tumblrTitleRespectsMaxLength() {
        let schema = ProviderSettingsCatalogB.tumblrSchema
        let longTitle = String(repeating: "a", count: 4097)
        let errors = schema.validate(["title": longTitle])
        #expect(errors.contains(.tooLong(key: "title", limit: 4096)))
    }

    @Test
    func tumblrLinkMustBeValidURL() {
        let schema = ProviderSettingsCatalogB.tumblrSchema
        let errors = schema.validate(["link": "not-a-url"])
        #expect(errors.contains(.invalidURL(key: "link")))
    }

    // MARK: - MeWe (required discriminator + conditional visibility)

    @Test
    func meweRequiresPostType() {
        let schema = ProviderSettingsCatalogB.meweSchema
        let errors = schema.validate([:])
        #expect(errors.contains(.missingRequiredField(key: "postType")))
    }

    @Test
    func meweGroupHiddenUnlessPostTypeIsGroup() {
        let schema = ProviderSettingsCatalogB.meweSchema
        let visible = schema.visibleFields(for: ["postType": "timeline"])
        #expect(!visible.contains { $0.key == "group" })

        let visibleWhenGroup = schema.visibleFields(for: ["postType": "group"])
        #expect(visibleWhenGroup.contains { $0.key == "group" })
    }

    // MARK: - Skool / Whop / Listmonk / Moltbook (required id-like text fields)

    @Test
    func skoolRequiresGroupLabelAndTitle() {
        let schema = ProviderSettingsCatalogB.skoolSchema
        let errors = schema.validate([:])
        #expect(errors.contains(.missingRequiredField(key: "group")))
        #expect(errors.contains(.missingRequiredField(key: "label")))
        #expect(errors.contains(.missingRequiredField(key: "title")))
    }

    @Test
    func whopRequiresCompanyAndExperience() {
        let schema = ProviderSettingsCatalogB.whopSchema
        let errors = schema.validate([:])
        #expect(errors.contains(.missingRequiredField(key: "company")))
        #expect(errors.contains(.missingRequiredField(key: "experience")))
        #expect(!errors.contains(.missingRequiredField(key: "title")))
    }

    @Test
    func listmonkRequiresSubjectPreviewAndList() {
        let schema = ProviderSettingsCatalogB.listmonkSchema
        let errors = schema.validate([:])
        #expect(errors.contains(.missingRequiredField(key: "subject")))
        #expect(errors.contains(.missingRequiredField(key: "preview")))
        #expect(errors.contains(.missingRequiredField(key: "list")))
        #expect(!errors.contains(.missingRequiredField(key: "template")))
    }

    @Test
    func moltbookRequiresSubmolt() {
        let schema = ProviderSettingsCatalogB.moltbookSchema
        let errors = schema.validate([:])
        #expect(errors.contains(.missingRequiredField(key: "submolt")))
    }
}
