import GRDB
import XCTest
@testable import CryptomatorCommonCore

final class HubDBRepositoryTests: XCTestCase {
	private var inMemoryDB: DatabaseQueue!
	private var repository: HubDBRepository!
	private var vaultAccountManager: VaultAccountManager!
	private var cloudAccountManager: CloudProviderAccountManager!

	override func setUpWithError() throws {
		repository = HubDBRepository()
		vaultAccountManager = VaultAccountDBManager()
		cloudAccountManager = CloudProviderAccountDBManager()
	}

	func testSaveAndRetrieve() throws {
		// GIVEN
		// a cloud account has been created
		let cloudAccount = CloudProviderAccount(accountUID: "", cloudProviderType: .dropbox)
		try cloudAccountManager.saveNewAccount(cloudAccount)

		// and a vault account has been created
		let vaultID = "123456789"
		let vaultAccount = VaultAccount(vaultUID: vaultID, delegateAccountUID: "", vaultPath: .init(""), vaultName: "")
		try vaultAccountManager.saveNewAccount(vaultAccount)

		// WHEN
		// saving a hub vault
		let vault = HubVault(vaultUID: vaultID, subscriptionState: .active)
		try repository.save(vault)

		// THEN
		// it can be retrieved
		let retrievedVault = try repository.getHubVault(vaultID: vaultID)
		XCTAssertEqual(vault, retrievedVault)
	}

	func testSaveToUpdate() throws {
		// GIVEN
		// a cloud account has been created
		let cloudAccount = CloudProviderAccount(accountUID: "", cloudProviderType: .dropbox)
		try cloudAccountManager.saveNewAccount(cloudAccount)

		// and a vault account has been created
		let vaultID = "123456789"
		let vaultAccount = VaultAccount(vaultUID: vaultID, delegateAccountUID: "", vaultPath: .init(""), vaultName: "")
		try vaultAccountManager.saveNewAccount(vaultAccount)

		// WHEN
		// saving a hub vault
		let initialVault = HubVault(vaultUID: vaultID, subscriptionState: .active)
		try repository.save(initialVault)

		// and saving the hub vault with the same vault ID but a changed subscription state
		let updatedVault = HubVault(vaultUID: vaultID, subscriptionState: .inactive)
		try repository.save(updatedVault)

		// THEN
		// it the updated version can be retrieved
		let retrievedVault = try repository.getHubVault(vaultID: vaultID)
		XCTAssertEqual(updatedVault, retrievedVault)
	}

	func testDeleteVaultAccountAlsoDeletesHubVault() throws {
		// GIVEN
		// a cloud account has been created
		let cloudAccount = CloudProviderAccount(accountUID: "", cloudProviderType: .dropbox)
		try cloudAccountManager.saveNewAccount(cloudAccount)

		// and a vault account has been created
		let vaultID = "123456789"
		let vaultAccount = VaultAccount(vaultUID: vaultID, delegateAccountUID: "", vaultPath: .init(""), vaultName: "")
		try vaultAccountManager.saveNewAccount(vaultAccount)

		// and a hub vault has been created for the vault id
		let vault = HubVault(vaultUID: vaultID, subscriptionState: .active)
		try repository.save(vault)

		// WHEN
		// the vault account gets deleted
		try vaultAccountManager.removeAccount(with: vaultID)

		// THEN
		// the hub vault account has been deleted and can not be retrieved
		let retrievedVault = try repository.getHubVault(vaultID: vaultID)
		XCTAssertNil(retrievedVault)
	}
}
