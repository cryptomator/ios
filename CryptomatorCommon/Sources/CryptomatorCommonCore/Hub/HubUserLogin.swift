import AppAuthCore
import CryptomatorCloudAccessCore
import Foundation

public protocol HubUserLogin {
	func authenticate(with hubConfig: HubConfig) async throws -> OIDAuthState
}
