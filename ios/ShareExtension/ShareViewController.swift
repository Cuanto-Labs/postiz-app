import UIKit
import SwiftUI

final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        let rootView = ShareRootView(onDone: { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        })
        let hostingController = UIHostingController(rootView: rootView)

        addChild(hostingController)
        hostingController.view.frame = view.bounds
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        hostingController.didMove(toParent: self)
    }
}

struct ShareRootView: View {
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Share to Cuanto Socials")
            Text(AppIdentifiers.appGroup)
            Button("Done", action: onDone)
        }
        .padding()
    }
}
