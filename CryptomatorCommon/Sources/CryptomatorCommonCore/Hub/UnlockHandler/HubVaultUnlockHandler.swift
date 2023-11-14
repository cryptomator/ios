import Foundation

public protocol HubVaultUnlockHandler {
	func didSuccessfullyRemoteUnlock(_ response: HubUnlockResponse) async
}

public protocol HubVaultUnlockHandlerDelegate: AnyObject {
	@MainActor
	func successfullyProcessedUnlockedVault()
	@MainActor
	func failedToProcessUnlockedVault(error: Error)
}
