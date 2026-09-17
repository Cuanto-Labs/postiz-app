import Foundation
import SocialsCore
import SwiftUI

@main
struct CuantoSocialsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
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
                    // UI tests launch with `-uiTestStub` to get the stub API + in-memory
                    // storage instead of the real network/Keychain. No other stub use.
                    let isUITestStub = ProcessInfo.processInfo.arguments.contains("-uiTestStub")
                    if isUITestStub {
                        environment = await AppEnvironment.preview()
                    } else {
                        environment = await AppEnvironment.live()
                    }
                    if let environment {
                        PushManager.shared.registrationViewModel = PushRegistrationViewModel(
                            api: environment.api)

                        let containerURL = FileManager.default.containerURL(
                            forSecurityApplicationGroupIdentifier: AppIdentifiers.appGroup)
                        let widgetFiles = SharedCacheFiles(
                            containerURL: isUITestStub
                                ? FileManager.default.temporaryDirectory
                                : (containerURL ?? FileManager.default.temporaryDirectory))
                        WidgetSnapshotRefresher.shared.configure(api: environment.api, files: widgetFiles)
                        WidgetSnapshotRefresher.shared.schedule()
                        await WidgetSnapshotRefresher.shared.refreshNow()
                    }
                }
            }
        }
    }
}
