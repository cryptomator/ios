//
//  DatabaseHelperMigrationTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Tobias Hagemann on 13.05.26.
//  Copyright © 2026 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import GRDB
import XCTest
@testable import CryptomatorFileProvider

/// Tests for `DatabaseHelper.repairCloudPathsMigration`.
///
/// The harness opens a fresh in-memory `DatabaseQueue`, runs `DatabaseHelper.migrate(_:)` to install
/// the schema (including a no-op v5 pass on the empty DB), seeds stale or disconnected rows via raw SQL,
/// and then invokes `DatabaseHelper.repairCloudPathsMigration(_:)` directly against the seeded state.
///
/// Seeded folder paths use the bare (`/A`) form to match what `CloudPath.appendingPathComponent` writes
/// during the repair, which makes the byte-level assertions deterministic.
class DatabaseHelperMigrationTests: XCTestCase {
	var database: DatabaseWriter!

	override func setUpWithError() throws {
		database = try DatabaseQueue()
		try DatabaseHelper.migrate(database)
	}

	func testRepairMigrationFixesStaleDescendant() throws {
		// /A/ (id=2, no children) and /Target/ (id=3) live under root.
		// B (id=4) is under /Target/ by parentID, but its stored cloudPath is stale at /A/B/.
		// C.txt (id=5) is under B by parentID, with stale cloudPath /A/B/C.txt.
		try database.write { db in
			try db.execute(sql: """
			INSERT INTO itemMetadata (id, name, type, size, parentID, lastModifiedDate, statusCode, cloudPath, isPlaceholderItem, isMaybeOutdated)
			VALUES
				(2, 'A', 'folder', NULL, 1, NULL, 'isUploaded', '/A', 0, 0),
				(3, 'Target', 'folder', NULL, 1, NULL, 'isUploaded', '/Target', 0, 0),
				(4, 'B', 'folder', NULL, 3, NULL, 'isUploaded', '/A/B', 0, 0),
				(5, 'C.txt', 'file', 0, 4, NULL, 'isUploaded', '/A/B/C.txt', 0, 0)
			""")
		}

		try database.write { db in
			try DatabaseHelper.repairCloudPathsMigration(db)
		}

		try assertCloudPath("/Target/B", forID: 4)
		try assertCloudPath("/Target/B/C.txt", forID: 5)
	}

	func testRepairMigrationFixesDeepStaleSubtree() throws {
		// Three-level subtree under /Target/ with stale paths still rooted at /A/.
		try database.write { db in
			try db.execute(sql: """
			INSERT INTO itemMetadata (id, name, type, size, parentID, lastModifiedDate, statusCode, cloudPath, isPlaceholderItem, isMaybeOutdated)
			VALUES
				(2, 'A', 'folder', NULL, 1, NULL, 'isUploaded', '/A', 0, 0),
				(3, 'Target', 'folder', NULL, 1, NULL, 'isUploaded', '/Target', 0, 0),
				(4, 'B', 'folder', NULL, 3, NULL, 'isUploaded', '/A/B', 0, 0),
				(5, 'C', 'folder', NULL, 4, NULL, 'isUploaded', '/A/B/C', 0, 0),
				(6, 'D.txt', 'file', 0, 5, NULL, 'isUploaded', '/A/B/C/D.txt', 0, 0)
			""")
		}

		try database.write { db in
			try DatabaseHelper.repairCloudPathsMigration(db)
		}

		try assertCloudPath("/Target/B", forID: 4)
		try assertCloudPath("/Target/B/C", forID: 5)
		try assertCloudPath("/Target/B/C/D.txt", forID: 6)
	}

	func testRepairMigrationLeavesCorrectRowsUntouched() throws {
		try database.write { db in
			try db.execute(sql: """
			INSERT INTO itemMetadata (id, name, type, size, parentID, lastModifiedDate, statusCode, cloudPath, isPlaceholderItem, isMaybeOutdated)
			VALUES
				(2, 'A', 'folder', NULL, 1, NULL, 'isUploaded', '/A', 0, 0),
				(3, 'B', 'folder', NULL, 2, NULL, 'isUploaded', '/A/B', 0, 0),
				(4, 'C.txt', 'file', 0, 3, NULL, 'isUploaded', '/A/B/C.txt', 0, 0)
			""")
		}
		let pathsBefore = try fetchCloudPathsByID()

		try database.write { db in
			try DatabaseHelper.repairCloudPathsMigration(db)
		}

		let pathsAfter = try fetchCloudPathsByID()
		XCTAssertEqual(pathsBefore, pathsAfter)
	}

	func testRepairMigrationLeavesDisconnectedRowsUntouched() throws {
		// Disconnected rows must bypass foreign-key checks during seeding:
		// - id=4 has parentID=9999 (no such parent).
		// - id=5 and id=6 form an X↔Y cycle that is not reachable from root.
		// A separate reachable stale row (id=7 under /Target/) verifies the migration still rewrites what it can.
		try database.write { db in
			try db.execute(sql: """
			INSERT INTO itemMetadata (id, name, type, size, parentID, lastModifiedDate, statusCode, cloudPath, isPlaceholderItem, isMaybeOutdated)
			VALUES
				(2, 'A', 'folder', NULL, 1, NULL, 'isUploaded', '/A', 0, 0),
				(3, 'Target', 'folder', NULL, 1, NULL, 'isUploaded', '/Target', 0, 0),
				(7, 'B', 'folder', NULL, 3, NULL, 'isUploaded', '/A/B', 0, 0)
			""")
		}
		// Corrupt-state seeds bypass the FK constraint on itemMetadata.parentID.
		// PRAGMA foreign_keys is a no-op inside a transaction, so the seeds run via writeWithoutTransaction.
		// `defer` restores FK enforcement even if any of the seed inserts throws.
		try database.writeWithoutTransaction { db in
			try db.execute(sql: "PRAGMA foreign_keys = OFF")
			defer { try? db.execute(sql: "PRAGMA foreign_keys = ON") }
			try db.execute(sql: """
			INSERT INTO itemMetadata (id, name, type, size, parentID, lastModifiedDate, statusCode, cloudPath, isPlaceholderItem, isMaybeOutdated)
			VALUES
				(4, 'Orphan', 'file', 0, 9999, NULL, 'isUploaded', '/orphan', 0, 0),
				(5, 'X', 'folder', NULL, 6, NULL, 'isUploaded', '/X', 0, 0),
				(6, 'Y', 'folder', NULL, 5, NULL, 'isUploaded', '/Y', 0, 0)
			""")
		}

		try database.write { db in
			try DatabaseHelper.repairCloudPathsMigration(db)
		}

		try assertCloudPath("/orphan", forID: 4)
		try assertCloudPath("/X", forID: 5)
		try assertCloudPath("/Y", forID: 6)
		try assertCloudPath("/Target/B", forID: 7)
	}

	func testRepairMigrationCreatesParentIDIndex() throws {
		try database.write { db in
			try DatabaseHelper.repairCloudPathsMigration(db)
		}
		let indexName = try database.read { db in
			try String.fetchOne(db, sql: "SELECT name FROM sqlite_master WHERE type='index' AND name='itemMetadata_parentID'")
		}
		XCTAssertEqual("itemMetadata_parentID", indexName)
	}

	func testRepairMigrationSkipsCanonicalPathConflict() throws {
		// /A (id=2) and /Target (id=3) live under root.
		// Row id=4 is parented to Target by parentID but its stored cloudPath is stale at /A/B.
		// Row id=5 already occupies the canonical /Target/B slot — the migration must leave id=4 at its stale path and log.
		// id=4 has a child id=6 at /A/B/C.txt; the migration must NOT descend into id=4's subtree after the skip, or the descendant
		// would be rewritten to /Target/B/C.txt under a parent that stayed at /A/B (split subtree).
		try database.write { db in
			try db.execute(sql: """
			INSERT INTO itemMetadata (id, name, type, size, parentID, lastModifiedDate, statusCode, cloudPath, isPlaceholderItem, isMaybeOutdated)
			VALUES
				(2, 'A', 'folder', NULL, 1, NULL, 'isUploaded', '/A', 0, 0),
				(3, 'Target', 'folder', NULL, 1, NULL, 'isUploaded', '/Target', 0, 0),
				(4, 'B', 'folder', NULL, 3, NULL, 'isUploaded', '/A/B', 0, 0),
				(5, 'B', 'folder', NULL, 3, NULL, 'isUploaded', '/Target/B', 0, 0),
				(6, 'C.txt', 'file', 0, 4, NULL, 'isUploaded', '/A/B/C.txt', 0, 0)
			""")
		}

		try database.write { db in
			try DatabaseHelper.repairCloudPathsMigration(db)
		}

		try assertCloudPath("/A/B", forID: 4)
		try assertCloudPath("/Target/B", forID: 5)
		try assertCloudPath("/A/B/C.txt", forID: 6)
	}

	func testRepairMigrationFixesBranchingSubtree() throws {
		// Branching tree exercises that the BFS index pointer advances across multiple
		// enqueued sibling folders before descending into either subtree.
		try database.write { db in
			try db.execute(sql: """
			INSERT INTO itemMetadata (id, name, type, size, parentID, lastModifiedDate, statusCode, cloudPath, isPlaceholderItem, isMaybeOutdated)
			VALUES
				(2, 'A', 'folder', NULL, 1, NULL, 'isUploaded', '/A', 0, 0),
				(3, 'Target', 'folder', NULL, 1, NULL, 'isUploaded', '/Target', 0, 0),
				(4, 'B', 'folder', NULL, 3, NULL, 'isUploaded', '/A/B', 0, 0),
				(5, 'L', 'folder', NULL, 4, NULL, 'isUploaded', '/A/B/L', 0, 0),
				(6, 'R', 'folder', NULL, 4, NULL, 'isUploaded', '/A/B/R', 0, 0),
				(7, 'L.txt', 'file', 0, 5, NULL, 'isUploaded', '/A/B/L/L.txt', 0, 0),
				(8, 'R.txt', 'file', 0, 6, NULL, 'isUploaded', '/A/B/R/R.txt', 0, 0)
			""")
		}

		try database.write { db in
			try DatabaseHelper.repairCloudPathsMigration(db)
		}

		try assertCloudPath("/Target/B", forID: 4)
		try assertCloudPath("/Target/B/L", forID: 5)
		try assertCloudPath("/Target/B/R", forID: 6)
		try assertCloudPath("/Target/B/L/L.txt", forID: 7)
		try assertCloudPath("/Target/B/R/R.txt", forID: 8)
	}

	func testRepairMigrationRunsAsRegisteredV5() throws {
		// Simulate a pre-v5 install: clear v5's GRDB marker and drop the index it created, seed a stale row,
		// then call DatabaseHelper.migrate(_:) so the migrator re-applies v5 end-to-end rather than via a direct helper call.
		try database.write { db in
			try db.execute(sql: "DELETE FROM grdb_migrations WHERE identifier = 'v5'")
			try db.execute(sql: "DROP INDEX IF EXISTS itemMetadata_parentID")
			try db.execute(sql: """
			INSERT INTO itemMetadata (id, name, type, size, parentID, lastModifiedDate, statusCode, cloudPath, isPlaceholderItem, isMaybeOutdated)
			VALUES
				(2, 'Target', 'folder', NULL, 1, NULL, 'isUploaded', '/Target', 0, 0),
				(3, 'B', 'folder', NULL, 2, NULL, 'isUploaded', '/A/B', 0, 0)
			""")
		}

		try DatabaseHelper.migrate(database)

		try assertCloudPath("/Target/B", forID: 3)
		let indexName = try database.read { db in
			try String.fetchOne(db, sql: "SELECT name FROM sqlite_master WHERE type='index' AND name='itemMetadata_parentID'")
		}
		XCTAssertEqual("itemMetadata_parentID", indexName)
	}

	func testRepairMigrationRunsAsRegisteredV5WithPreExistingOrphan() throws {
		// Pre-existing orphan rows would fail the default deferred-FK check at COMMIT time.
		// v5 registers with foreignKeyChecks: .immediate so the FK sweep only checks rows the migration modifies.
		// This test proves the registered migration tolerates an orphan (`parentID = 9999`) on its way through the migrator.
		try database.write { db in
			try db.execute(sql: "DELETE FROM grdb_migrations WHERE identifier = 'v5'")
			try db.execute(sql: "DROP INDEX IF EXISTS itemMetadata_parentID")
		}
		try database.writeWithoutTransaction { db in
			try db.execute(sql: "PRAGMA foreign_keys = OFF")
			defer { try? db.execute(sql: "PRAGMA foreign_keys = ON") }
			try db.execute(sql: """
			INSERT INTO itemMetadata (id, name, type, size, parentID, lastModifiedDate, statusCode, cloudPath, isPlaceholderItem, isMaybeOutdated)
			VALUES
				(2, 'Orphan', 'file', 0, 9999, NULL, 'isUploaded', '/orphan', 0, 0)
			""")
		}

		try DatabaseHelper.migrate(database)

		try assertCloudPath("/orphan", forID: 2)
	}

	private func assertCloudPath(_ expected: String, forID id: Int64, file: StaticString = #file, line: UInt = #line) throws {
		let actual = try database.read { db in
			try String.fetchOne(db, sql: "SELECT cloudPath FROM itemMetadata WHERE id = ?", arguments: [id])
		}
		XCTAssertEqual(expected, actual, "Unexpected cloudPath for id=\(id)", file: file, line: line)
	}

	private func fetchCloudPathsByID() throws -> [Int64: String] {
		try database.read { db in
			let rows = try Row.fetchAll(db, sql: "SELECT id, cloudPath FROM itemMetadata")
			return rows.reduce(into: [Int64: String]()) { acc, row in
				acc[row["id"]] = row["cloudPath"]
			}
		}
	}
}
