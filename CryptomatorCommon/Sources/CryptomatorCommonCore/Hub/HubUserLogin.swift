import AppAuthCore
import CryptomatorCloudAccessCore
import Foundation

public protocol HubUserLogin {
	@MainActor
	func authenticate(with hubConfig: HubConfig) async throws -> OIDAuthState
}
