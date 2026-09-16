import SwiftUI

@main
struct CuantoSocialsApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {
    var body: some View {
        VStack {
            Text("Cuanto Socials")
            Text(BuildConfig.apiBaseURL.absoluteString)
        }
    }
}
