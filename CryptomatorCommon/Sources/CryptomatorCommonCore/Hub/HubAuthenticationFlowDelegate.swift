import CryptoKit
import JOSESwift

public protocol HubAuthenticationFlowDelegate: AnyObject {
	func receivedExistingKey(jwe: JWE, privateKey: P384.KeyAgreement.PrivateKey) async
}
