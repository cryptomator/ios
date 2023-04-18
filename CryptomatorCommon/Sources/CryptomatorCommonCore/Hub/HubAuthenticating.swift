import AppAuthCore
import CryptomatorCloudAccessCore
import UIKit

public protocol HubAuthenticating {
	func authenticate(with hubConfig: HubConfig, from viewController: UIViewController) async throws -> OIDAuthState
}
