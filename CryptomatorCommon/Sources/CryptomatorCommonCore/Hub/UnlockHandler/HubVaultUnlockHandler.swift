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

// MARK: - HubVaultUnlockHandlerMock -

#if DEBUG
// swiftlint: disable all
final class HubVaultUnlockHandlerMock: HubVaultUnlockHandler {
	// MARK: - didSuccessfullyRemoteUnlock

	var didSuccessfullyRemoteUnlockCallsCount = 0
	var didSuccessfullyRemoteUnlockCalled: Bool {
		didSuccessfullyRemoteUnlockCallsCount > 0
	}

	var didSuccessfullyRemoteUnlockReceivedResponse: HubUnlockResponse?
	var didSuccessfullyRemoteUnlockReceivedInvocations: [HubUnlockResponse] = []
	var didSuccessfullyRemoteUnlockClosure: ((HubUnlockResponse) -> Void)?

	func didSuccessfullyRemoteUnlock(_ response: HubUnlockResponse) {
		didSuccessfullyRemoteUnlockCallsCount += 1
		didSuccessfullyRemoteUnlockReceivedResponse = response
		didSuccessfullyRemoteUnlockReceivedInvocations.append(response)
		didSuccessfullyRemoteUnlockClosure?(response)
	}
}
// / swiftlint: enable all
#endif
