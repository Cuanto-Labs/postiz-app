import AppIntents

@main
struct CuantoSocialsIntentsExtension: AppIntentsExtension {}

struct OpenCuantoSocialsIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Cuanto Socials"
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        .result()
    }
}
