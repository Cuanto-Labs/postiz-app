# Cuanto Socials — brand spec

Derived from the real web app (`apps/frontend/src/app/colors.scss`, `global.scss`,
`tailwind.config.cjs`, `(app)/layout.tsx`) on 2026-09-17, so iOS and web read as one product.
Read by every `skills/ios-design` pass and the render→critique→fix loop.

## One sentence

Cuanto Socials is a social-publishing console for operators who schedule for many channels, and
it feels **utilitarian** — near-black, low-chroma, function-first, with colour reserved for
state and the one action that matters. Everything below serves that sentence.

## Appearance

The web product is dark-only (root layout hardcodes `dark` + `!bg-primary`, there is no light
path in-app). iOS therefore ships **dark-first**: the app sets `.preferredColorScheme(.dark)`
so the brand reads identically to web. Widgets and the share extension are the exception —
they render inside system surfaces that follow the device, so their tokens must resolve in
both appearances. Light values below exist for that reason, not for an in-app toggle.

## Hierarchy — what wins on every screen

- **Primary object:** the scheduled post — its time, its channels, its text.
- **Primary action:** one per screen, in the thumb zone — Calendar: "New post"; Composer:
  "Add to calendar"; Channels: "Connect channel".
- **What we deliberately hide:** per-channel overrides, tags, analytics breakdowns, webhooks,
  team and org settings → detail views and sheets, never the first screen.

## Clutter budget (hard caps — `skills/ios-design/clutter-budget.md`)

| Cap | Value | App override (justify) |
|---|---|---|
| primary actions / screen | 1 | — |
| secondary actions / screen | ≤2 | Composer: 3 (Save draft / Add to calendar / Post now) — the web composer's three-way commit is the product's core verb set; dropping one would change behaviour, not just looks |
| type sizes / screen | ≤3 | — |
| colors incl. semantic / screen | ≤5 | — |
| custom glass surfaces / screen | ≤1 | — |
| top-level elements before split | ≤7 | — |

## Color (CuantoKit tokens — `Color.token(_, in: theme)`)

Values are the web app's own custom properties; the hex is the contract, the token is the API.

| Role | Token | Light | Dark (canonical) | Where |
|---|---|---|---|---|
| Brand / primary action | `.primary` | #0f9f74 | #10b981 | the ONE primary action, active tab, "connected" state |
| Selection tint / AI | `.accent` | #4f46e5 | #6366f1 | AI features, toggles-on, active settings row — never a post CTA |
| Background | `.background` | system | #0e0e0e | screen |
| Surface | `.card` | system | #1a1919 | post cards, channel tiles, stat tiles |
| Hairline | `.border` | system | #252525 | cell borders, dividers, input outlines |
| Text | `.foreground` / `.mutedForeground` | `.primary` / `.secondary` | #ffffff / #999999 | never `.black`/`.white` literals |
| Semantic | `.success` / `.destructive` | system | #10b981 / #b91c1c | status only, never decoration |

Green means "go / connected / primary action". Indigo means "AI or switched on". They are not
interchangeable — the web app is strict about this and so is iOS. No gradients: the tone word is
utilitarian, and the lint blocks purple-first gradients anyway.

## Type (text styles only — Dynamic Type is not optional)

Web uses Plus Jakarta Sans at 600/500. iOS bundles the same OFL family and maps it through
`.custom(_:size:relativeTo:)` so Dynamic Type still scales every level.

| Level | Text style | Font / weight | Used for |
|---|---|---|---|
| Hero | `.title` | PlusJakartaSans-Bold | the primary object, once per screen |
| Section | `.headline` | PlusJakartaSans-SemiBold (600) | group labels, nav titles |
| Body | `.body` | PlusJakartaSans-Medium (500) | post text, form values |
| Meta | `.footnote` / `.caption` | PlusJakartaSans-Medium, `.mutedForeground` | timestamps, counts, char limits |

Design: `.default` (the custom family replaces it). Fixed `.system(size:)` stays banned.

## Spacing & shape

- Grid: 8pt (`theme.spacing.xs/sm/md/lg/xl` = 4/8/16/24/32). Horizontal screen inset 16pt.
- Corner radius: web's dominant radius is 8px with pills for avatars/chips, so `theme.radius.sm`
  (8) for cards, tiles and inputs, `.capsule` for chips, avatars and segmented controls,
  `theme.radius.lg` for sheets. Nested corners concentric on iOS 26+.
- Glass: none. The web app is flat dark surfaces; system bars supply the only glass.

## Motion (matching web, not exceeding it)

The web app animates with CSS only: 150ms `transition-colors` on controls, 200–500ms
`ease-in-out` fades for entrances (`fadeIn`, `fadeDown`), 500ms accordion reveals. iOS maps that to:

| Web | iOS |
|---|---|
| `transition-colors` 150ms | `.animation(.easeInOut(duration: 0.15), value:)` on state colour |
| `fadeIn` / `fadeDown` 200–500ms | `.transition(.opacity.combined(with: .move(edge: .top)))`, `.smooth(duration: 0.3)` |
| accordion `overFlow` 500ms | `.smooth(duration: 0.35)` height/disclosure |
| (web has none) | `matchedGeometryEffect` for calendar post → post detail, and composer channel chip → preview |

Motion is confirmation, never decoration: it tracks a state change the user caused. No spring
bounce on data, no parallax, nothing that fires without input.

## Iconography & icon

- SF Symbols only, **monochrome** rendering app-wide (matches web's single-weight icon rail);
  channel/provider marks are brand assets, not symbols.
- App icon: layered `.icon` bundle. Concept: the Cuanto mark, one green accent, no text.

## Voice

- Buttons are verbs: "Add to calendar", "Connect channel", "Post now" — never "OK"/"Submit".
- Empty state: one line of what to do plus the action ("Nothing scheduled this week. New post").
- Errors: what happened + one recovery ("Instagram needs reconnecting. Reconnect").

## Reference screens (what "done" looks like)

- The web app itself: `/tmp/socials-web-ui/{calendar-week,calendar-month,composer-modal,channels,analytics,settings}.png`
  (ignore the orange superadmin debug bar — internal-only overlay).
- Archetype exemplars: `skills/ios-design/archetypes/`.
- Apple apps setting the bar: Calendar for the week grid's density, Mail for list-to-detail
  hierarchy, Photos for the media picker's grid rhythm.
