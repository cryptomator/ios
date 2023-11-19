import AppAuthCore
import CryptomatorCloudAccessCore
import Dependencies
import UIKit

public protocol HubAuthenticating {
	func authenticate(with hubConfig: HubConfig, from viewController: UIViewController) async throws -> OIDAuthState
}

public enum HubAuthenticatingKey: TestDependencyKey {
	public static var testValue: HubAuthenticating = UnimplementedHubAuthenticatingService()
}

public extension DependencyValues {
	var hubAuthenticationService: HubAuthenticating {
		get { self[HubAuthenticatingKey.self] }
		set { self[HubAuthenticatingKey.self] = newValue }
	}
}

struct UnimplementedHubAuthenticatingService: HubAuthenticating {
	func authenticate(with hubConfig: CryptomatorCloudAccessCore.HubConfig, from viewController: UIViewController) async throws -> OIDAuthState {
		unimplemented(placeholder: OIDAuthState(authorizationResponse: .init(request: .init(configuration: .init(authorizationEndpoint: URL(string: "example.com")!, tokenEndpoint: URL(string: "example.com")!), clientId: "", scopes: nil, redirectURL: URL(string: "example.com")!, responseType: "code", additionalParameters: nil), parameters: [:])))
	}
}
