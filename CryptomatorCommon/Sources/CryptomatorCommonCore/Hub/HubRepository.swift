import Dependencies
import Foundation
import GRDB

public protocol HubRepository {
	func save(_ vault: HubVault) throws
	func getHubVault(vaultID: String) throws -> HubVault?
}

public struct HubVault: Equatable {
	public let vaultUID: String
	public let subscriptionState: HubSubscriptionState
}

private struct HubVaultRow: Codable, Equatable, PersistableRecord, FetchableRecord {
	public static let databaseTableName = "hubVaultAccount"

	let vaultUID: String
	let subscriptionState: HubSubscriptionState

	init(from vault: HubVault) {
		self.vaultUID = vault.vaultUID
		self.subscriptionState = vault.subscriptionState
	}

	func toHubVault() -> HubVault {
		HubVault(vaultUID: vaultUID, subscriptionState: subscriptionState)
	}

	enum Columns: String, ColumnExpression {
		case vaultUID, subscriptionState
	}

	public func encode(to container: inout PersistenceContainer) {
		container[Columns.vaultUID] = vaultUID
		container[Columns.subscriptionState] = subscriptionState
	}
}

extension HubSubscriptionState: DatabaseValueConvertible {}

public extension DependencyValues {
	var hubRepository: HubRepository {
		get { self[HubRepositoryKey.self] }
		set { self[HubRepositoryKey.self] = newValue }
	}
}

private enum HubRepositoryKey: DependencyKey {
	static var liveValue: HubRepository = HubDBRepository()
	#if DEBUG
	static var testValue: HubRepository = HubRepositoryMock()
	#endif
}

public class HubDBRepository: HubRepository {
	@Dependency(\.database) private var database

	public func save(_ vault: HubVault) throws {
		let row = HubVaultRow(from: vault)
		try database.write { db in
			try row.save(db)
		}
	}

	public func getHubVault(vaultID: String) throws -> HubVault? {
		let row = try database.read { db in
			try HubVaultRow.fetchOne(db, key: vaultID)
		}
		return row?.toHubVault()
	}
}
