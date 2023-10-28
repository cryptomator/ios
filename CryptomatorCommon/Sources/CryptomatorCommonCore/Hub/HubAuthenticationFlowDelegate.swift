import CryptoKit
import JOSESwift

public protocol HubAuthenticationFlowDelegate: AnyObject {
	func didSuccessfullyRemoteUnlock(_ response: HubUnlockResponse) async
}

public struct HubUnlockResponse {
	public let jwe: JWE
	public let privateKey: P384.KeyAgreement.PrivateKey
	public let subscriptionState: HubSubscriptionState
}
