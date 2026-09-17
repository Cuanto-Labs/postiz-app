import Foundation
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
                    ProgressView()
                }
            }
            .task {
                if environment == nil {
                    // UI tests launch with `-uiTestStub` to get `StubSocialsAPI` + in-memory
                    // storage instead of the real network/Keychain. No other stub use.
                    if ProcessInfo.processInfo.arguments.contains("-uiTestStub") {
                        environment = await AppEnvironment.preview()
                    } else {
                        environment = await AppEnvironment.live()
                    }
                }
            }
        }
    }
}
