import Foundation

#if DEBUG

// MARK: - HubRepositoryMock -

final class HubRepositoryMock: HubRepository {
	// MARK: - save

	var saveThrowableError: Error?
	var saveCallsCount = 0
	var saveCalled: Bool {
		saveCallsCount > 0
	}

	var saveReceivedVault: HubVault?
	var saveReceivedInvocations: [HubVault] = []
	var saveClosure: ((HubVault) throws -> Void)?

	func save(_ vault: HubVault) throws {
		if let error = saveThrowableError {
			throw error
		}
		saveCallsCount += 1
		saveReceivedVault = vault
		saveReceivedInvocations.append(vault)
		try saveClosure?(vault)
	}

	// MARK: - getHubVault

	var getHubVaultVaultIDThrowableError: Error?
	var getHubVaultVaultIDCallsCount = 0
	var getHubVaultVaultIDCalled: Bool {
		getHubVaultVaultIDCallsCount > 0
	}

	var getHubVaultVaultIDReceivedVaultID: String?
	var getHubVaultVaultIDReceivedInvocations: [String] = []
	var getHubVaultVaultIDReturnValue: HubVault?
	var getHubVaultVaultIDClosure: ((String) throws -> HubVault?)?

	func getHubVault(vaultID: String) throws -> HubVault? {
		if let error = getHubVaultVaultIDThrowableError {
			throw error
		}
		getHubVaultVaultIDCallsCount += 1
		getHubVaultVaultIDReceivedVaultID = vaultID
		getHubVaultVaultIDReceivedInvocations.append(vaultID)
		return try getHubVaultVaultIDClosure.map({ try $0(vaultID) }) ?? getHubVaultVaultIDReturnValue
	}
}
#endif
