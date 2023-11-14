import AppAuthCore
import CryptomatorCloudAccessCore
import UIKit

struct HubUserAuthenticator: HubUserLogin {
	private let hubAuthenticator: HubAuthenticating
	private let viewController: UIViewController

	init(hubAuthenticator: HubAuthenticating, viewController: UIViewController) {
		self.hubAuthenticator = hubAuthenticator
		self.viewController = viewController
	}

	func authenticate(with hubConfig: HubConfig) async throws -> OIDAuthState {
		try await hubAuthenticator.authenticate(with: hubConfig, from: viewController)
	}
}
