//
//  SaveFileIntentHandler.swift
//  CryptomatorIntents
//
//  Created by Philipp Schmid on 13.05.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import Dependencies
import FileProvider
import Foundation
import Intents
import Promises

class SaveFileIntentHandler: NSObject, SaveFileIntentHandling {
	@Dependency(\.fileProviderConnector) private var fileProviderConnector

	func handle(intent: SaveFileIntent) async -> SaveFileIntentResponse {
		guard let vaultFolder = intent.folder, let vaultIdentifier = vaultFolder.vaultIdentifier, let folderIdentifier = vaultFolder.identifier else {
			return SaveFileIntentResponse(failureReason: LocalizedString.getValue("intents.saveFile.invalidFolder"))
		}
		guard let fileURL = intent.file?.fileURL else {
			return SaveFileIntentResponse(failureReason: LocalizedString.getValue("intents.saveFile.missingFile"))
		}
		guard let tmpFolderURL = FileManager.default.appGroupCacheDirectory?.appendingPathComponent(UUID().uuidString) else {
			return SaveFileIntentResponse(failureReason: LocalizedString.getValue("intents.saveFile.missingTemporaryFolder"))
		}
		let tmpFileURL = tmpFolderURL.appendingPathComponent(fileURL.lastPathComponent)
		let shouldStopAccess = fileURL.startAccessingSecurityScopedResource()
		defer {
			if shouldStopAccess {
				fileURL.stopAccessingSecurityScopedResource()
			}
			try? FileManager.default.removeItem(at: tmpFolderURL)
		}
		do {
			try FileManager.default.createDirectory(at: tmpFolderURL, withIntermediateDirectories: true, attributes: nil)
			try FileManager.default.copyItem(at: fileURL, to: tmpFileURL)
		} catch {
			DDLogError("Copy item to shared tmp folder failed with error: \(error)")
			return SaveFileIntentResponse(error: error)
		}

		let domainIdentifier = NSFileProviderDomainIdentifier(vaultIdentifier)
		do {
			try await importFile(at: tmpFileURL, toParentItemIdentifier: folderIdentifier, domainIdentifier: domainIdentifier)
		} catch NSFileProviderError.notAuthenticated {
			return SaveFileIntentResponse(failureReason: LocalizedString.getValue("intents.saveFile.lockedVault"))
		} catch NSFileProviderError.filenameCollision {
			if intent.shouldIgnoreExisting {
				// Ignore filename collision - warning this also ignores changes to existing files!
				return .success
			} else {
				return .failure(CocoaError(.fileWriteFileExists))
			}
		} catch FileProviderXPCConnectorError.domainNotFound {
			return SaveFileIntentResponse(failureReason: LocalizedString.getValue("intents.saveFile.selectedVaultNotFound"))
		} catch {
			return SaveFileIntentResponse(error: error)
		}
		return .success
	}

	@available(iOSApplicationExtension 14.0, *)
	func provideFolderOptionsCollection(for intent: SaveFileIntent) async throws -> INObjectCollection<VaultFolder> {
		// Returns an empty collection, since dynamic options are only supported to use the magic variable in the Shortcuts app
		return INObjectCollection(items: [])
	}

	@available(iOS, introduced: 13.0, deprecated: 14.0, message: "")
	func provideFolderOptions(for intent: SaveFileIntent, with completion: @escaping ([VaultFolder]?, Error?) -> Void) {
		// Returns an empty collection, since dynamic options are only supported to use the magic variable in the Shortcuts app
		completion([], nil)
	}

	@available(iOSApplicationExtension 14.0, *)
	func provideFileOptionsCollection(for intent: SaveFileIntent) async throws -> INObjectCollection<INFile> {
		return INObjectCollection(items: [])
	}

	@available(iOS, introduced: 13.0, deprecated: 14.0, message: "")
	func provideFileOptionsCollection(for intent: SaveFileIntent, with completion: @escaping ([INFile]?, Error?) -> Void) {
		// Returns an empty collection, since dynamic options are only supported to use the magic variable in the Shortcuts app
		completion([], nil)
	}

	private func importFile(at localURL: URL, toParentItemIdentifier parentItemIdentifier: String, domainIdentifier: NSFileProviderDomainIdentifier) async throws {
		let getXPCPromise: Promise<XPC<FileImporting>> = fileProviderConnector.getXPC(serviceName: .fileImporting, domainIdentifier: domainIdentifier)
		try await withCheckedThrowingContinuation({ continuation in
			getXPCPromise.then { xpc in
				xpc.proxy.importFile(at: localURL, toParentItemIdentifier: parentItemIdentifier)
			}.then {
				continuation.resume()
			}.catch {
				continuation.resume(throwing: $0)
			}.always { [fileProviderConnector] in
				fileProviderConnector.invalidateXPC(getXPCPromise)
			}
		})
	}
}

extension SaveFileIntentResponse {
	static var success: SaveFileIntentResponse { SaveFileIntentResponse(code: .success, userActivity: nil) }

	static func failure(_ error: Error) -> SaveFileIntentResponse {
		return SaveFileIntentResponse(error: error)
	}

	convenience init(error: Error) {
		self.init(failureReason: error.localizedDescription)
	}

	convenience init(failureReason: String) {
		self.init(code: .failure, userActivity: nil)
		self.failureReason = failureReason
	}
}

extension CloudProviderType {
	var assetName: String {
		switch self {
		case .dropbox:
			return "dropbox-vault"
		case .googleDrive:
			return "google-drive-vault"
		case .oneDrive:
			return "onedrive-vault"
		case .pCloud:
			return "pcloud-vault"
		case .webDAV:
			return "webdav-vault"
		case let .localFileSystem(type):
			return type.assetName
		case .s3:
			return "s3-vault"
		}
	}
}

extension LocalFileSystemType {
	var assetName: String {
		switch self {
		case .custom:
			return "file-provider-vault"
		case .iCloudDrive:
			return "icloud-drive-vault"
		}
	}
}

extension INImage {
	convenience init(type: CloudProviderType) {
		self.init(named: type.assetName)
	}
}

extension SaveFileIntent {
	var shouldIgnoreExisting: Bool {
		return ignoreExisting as? Bool ?? false
	}
}

extension FileManager {
	var appGroupCacheDirectory: URL? {
		let appGroupDirectory = containerURL(forSecurityApplicationGroupIdentifier: CryptomatorConstants.appGroupName)
		return appGroupDirectory?.appendingPathComponent("Library/Caches")
	}
}
