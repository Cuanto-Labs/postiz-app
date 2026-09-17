import SwiftUI

@main
struct CuantoSocialsApp: App {
    @State private var environment: AppEnvironment?

    var body: some Scene {
        WindowGroup {
            Group {
                if let environment {
                    RootView().environment(environment)
                } else {
                    RootView()
                }
            }
            .task {
                if environment == nil {
                    environment = await AppEnvironment.live()
                }
            }
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
