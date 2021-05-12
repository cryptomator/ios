//
//  FileProviderExtension.swift
//  FileProviderExtension
//
//  Created by Philipp Schmid on 17.06.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjack
import CocoaLumberjackSwift
import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import CryptomatorFileProvider
import FileProvider
import MSAL

class FileProviderExtension: NSFileProviderExtension {
	var fileManager = FileManager()
	let fileCoordinator = NSFileCoordinator()
	var decorator: FileProviderDecorator?
	var observation: NSKeyValueObservation?
	var manager: NSFileProviderManager?
	var dbPath: URL?
	var notificator: FileProviderNotificator?
	static var databaseError: Error?
	static var sharedDatabaseInitialized = false
	override init() {
		super.init()
		LoggerSetup.oneTimeSetup()
		if !FileProviderExtension.sharedDatabaseInitialized {
			if let dbURL = CryptomatorDatabase.sharedDBURL {
				do {
					let dbPool = try CryptomatorDatabase.openSharedDatabase(at: dbURL)
					CryptomatorDatabase.shared = try CryptomatorDatabase(dbPool)
					FileProviderExtension.sharedDatabaseInitialized = true
					OneDriveSetup.appGroupName = CryptomatorConstants.appGroupName
					let oneDriveConfiguration = MSALPublicClientApplicationConfig(clientId: CloudAccessSecrets.oneDriveClientId, redirectUri: CloudAccessSecrets.oneDriveRedirectUri, authority: nil)
					oneDriveConfiguration.cacheConfig.keychainSharingGroup = CryptomatorConstants.mainAppBundleId
					OneDriveSetup.clientApplication = try MSALPublicClientApplication(configuration: oneDriveConfiguration)

				} catch {
					// MARK: Handle error

					FileProviderExtension.databaseError = error
					DDLogError("Failed to initialize FPExt sharedDB: \(error)")
				}
			} else {
				// MARK: Handle error

				DDLogError("FPExt - dbURL is nil")
			}
		}

		self.observation = observe(
			\.domain,
			options: [.old, .new]
		) { _, change in
			DDLogInfo("domain changed from: \(change.oldValue) to: \(change.newValue)")
//			if let domain = self.domain {
//				guard let manager = NSFileProviderManager(for: domain) else {
//					return
//				}
//				let dbPath = manager.documentStorageURL.appendingPathComponent(domain.pathRelativeToDocumentStorage, isDirectory: true).appendingPathComponent("db.sqlite")
//				self.decorator = try? DecoratorManager.getDecorator(for: domain, with: manager, dbPath: dbPath)
//				self.manager = manager
//			}
			do {
				try self.setUp()
			} catch {
				DDLogError("setUp decorator from kvo failed: \(error)")
			}
		}
	}

	deinit {
		observation?.invalidate()
		fileCoordinator.cancel()
	}

	override func item(for identifier: NSFileProviderItemIdentifier) throws -> NSFileProviderItem {
		// resolve the given identifier to a record in the model
		// TODO: implement the actual lookup
		// TODO: Change domain stuff, decorator init, etc.
		guard let decorator = self.decorator else {
			// no domain ==> no installed vault
			// TODO: Change error Code here
			throw NSFileProviderError(.notAuthenticated)
		}
		return try decorator.getFileProviderItem(for: identifier)
	}

	override func urlForItem(withPersistentIdentifier identifier: NSFileProviderItemIdentifier) -> URL? {
		// resolve the given identifier to a file on disk

		guard let item = try? item(for: identifier) else {
			return nil
		}

		// in this implementation, all paths are structured as <base storage directory>/<item identifier>/<item file name>
		let domainDocumentStorage = domain!.pathRelativeToDocumentStorage
		let manager = NSFileProviderManager.default
		let domainURL = manager.documentStorageURL.appendingPathComponent(domainDocumentStorage)
		let perItemDirectory = domainURL.appendingPathComponent(identifier.rawValue, isDirectory: true)
		return perItemDirectory.appendingPathComponent(item.filename, isDirectory: false)
	}

	override func persistentIdentifierForItem(at url: URL) -> NSFileProviderItemIdentifier? {
		// resolve the given URL to a persistent identifier using a database
		let pathComponents = url.pathComponents

		// exploit the fact that the path structure has been defined as
		// <base storage directory>/<item identifier>/<item file name> above
		assert(pathComponents.count > 2)

		return NSFileProviderItemIdentifier(pathComponents[pathComponents.count - 2])
	}

	override func providePlaceholder(at url: URL, completionHandler: @escaping (Error?) -> Void) {
		guard let identifier = persistentIdentifierForItem(at: url) else {
			completionHandler(NSFileProviderError(.noSuchItem))
			return
		}
		do {
			let fileProviderItem = try item(for: identifier)
			let placeholderURL = NSFileProviderManager.placeholderURL(for: url)
			try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
			try NSFileProviderManager.writePlaceholder(at: placeholderURL, withMetadata: fileProviderItem)
			completionHandler(nil)
		} catch {
			completionHandler(error)
		}
	}

	// swiftlint:disable:next function_body_length
	override func startProvidingItem(at url: URL, completionHandler: @escaping ((_ error: Error?) -> Void)) {
		// Should ensure that the actual file is in the position returned by URLForItemWithIdentifier:, then call the completion handler

		/* TODO:
		 This is one of the main entry points of the file provider. We need to check whether the file already exists on disk,
		 whether we know of a more recent version of the file, and implement a policy for these cases. Pseudocode:

		 if !fileOnDisk {
		     downloadRemoteFile()
		     callCompletion(downloadErrorOrNil)
		 } else if fileIsCurrent {
		     callCompletion(nil)
		 } else {
		     if localFileHasChanges {
		         // in this case, a version of the file is on disk, but we know of a more recent version
		         // we need to implement a strategy to resolve this conflict
		         moveLocalFileAside()
		         scheduleUploadOfLocalFile()
		         downloadRemoteFile()
		         callCompletion(downloadErrorOrNil)
		     } else {
		         downloadRemoteFile()
		         callCompletion(downloadErrorOrNil)
		     }
		 }
		 */
		// TODO: Register DownloadTask
		guard let decorator = self.decorator else {
			// no domain ==> no installed vault
			// TODO: Change error Code here
			completionHandler(NSFileProviderError(.notAuthenticated))
			return
		}
		guard let identifier = persistentIdentifierForItem(at: url) else {
			completionHandler(NSFileProviderError(.noSuchItem))
			return
		}

		if !fileManager.fileExists(atPath: url.path) {
			decorator.downloadFile(with: identifier, to: url).then { item in
				self.notificator?.fileProviderSignalUpdateContainerItem[item.itemIdentifier] = item
				self.notificator?.signalEnumerator(for: [item.parentItemIdentifier, item.itemIdentifier])
				completionHandler(nil)
			}.catch { error in
				completionHandler(error)
			}
		} else {
			decorator.localFileIsCurrent(with: identifier).then { isCurrent in
				if isCurrent {
					completionHandler(nil)
				} else {
					// if localFileHasChanges DO:
					// TODO: Implement the following Logic
					// Move LocalFile in Tmp Folder
					// Call import Document
					// after completionHandler returned (immediately) delete localFile in tmp folder
					let hasVersioningConflict: Bool
					do {
						hasVersioningConflict = try decorator.hasPossibleVersioningConflictForItem(withIdentifier: identifier)
					} catch {
						completionHandler(error)
						return
					}
					if hasVersioningConflict {
						let tmpDirectory = self.fileManager.temporaryDirectory
						let tmpFileURL = tmpDirectory.appendingPathComponent(url.lastPathComponent)
						let parentIdentifier: NSFileProviderItemIdentifier
						do {
							try self.fileManager.createDirectory(at: tmpDirectory, withIntermediateDirectories: false, attributes: nil)
							try self.fileManager.moveItem(at: url, to: tmpFileURL)
							parentIdentifier = try self.item(for: identifier).parentItemIdentifier
						} catch {
							completionHandler(error)
							return
						}
						self.importDocument(at: tmpFileURL, toParentItemIdentifier: parentIdentifier) { _, error in
							if let error = error {
								completionHandler(error)
								return
							}
							do {
								try self.fileManager.removeItem(at: tmpFileURL)
							} catch {
								completionHandler(error)
								return
							}
							decorator.downloadFile(with: identifier, to: url, replaceExisting: true).then { item in
								self.notificator?.fileProviderSignalUpdateContainerItem[item.itemIdentifier] = item
								self.notificator?.signalEnumerator(for: [item.parentItemIdentifier, item.itemIdentifier])
								completionHandler(nil)
							}.catch { error in
								completionHandler(error)
							}
						}
					} else {
						decorator.downloadFile(with: identifier, to: url, replaceExisting: true).then { item in
							self.notificator?.fileProviderSignalUpdateContainerItem[item.itemIdentifier] = item
							self.notificator?.signalEnumerator(for: [item.parentItemIdentifier, item.itemIdentifier])
							completionHandler(nil)
						}.catch { error in
							completionHandler(error)
						}
					}
				}
			}
		}
	}

	override func itemChanged(at url: URL) {
		// Called at some point after the file has changed; the provider may then trigger an upload

		/* TODO:
		 - mark file at <url> as needing an update in the model
		 - if there are existing NSURLSessionTasks uploading this file, cancel them
		 - create a fresh background NSURLSessionTask and schedule it to upload the current modifications
		 - register the NSURLSessionTask with NSFileProviderManager to provide progress updates
		 */

		guard let decorator = self.decorator else {
			// no domain ==> no installed vault
			return
		}
		guard let itemIdentifier = persistentIdentifierForItem(at: url) else {
			return
		}
		guard let metadata = try? decorator.registerFileInUploadQueue(with: url, identifier: itemIdentifier) else {
			return
		}

		decorator.uploadFile(with: url, itemMetadata: metadata).then { item in
			self.notificator?.fileProviderSignalUpdateContainerItem[item.itemIdentifier] = item
			self.notificator?.signalEnumerator(for: [item.parentItemIdentifier, item.itemIdentifier])
		}.catch { error in
			print("itemChanged Error: \(error)")
		}
	}

	override func stopProvidingItem(at url: URL) {
		// ### Apple template comments: ###
		// Called after the last claim to the file has been released. At this point, it is safe for the file provider to remove the content file.
		// Care should be taken that the corresponding placeholder file stays behind after the content file has been deleted.

		// Called after the last claim to the file has been released. At this point, it is safe for the file provider to remove the content file.

		// TODO: look up whether the file has local changes
		//		let fileHasLocalChanges = false
		//
		//		if !fileHasLocalChanges {
		//			// remove the existing file to free up space
		//			do {
		//				_ = try FileManager.default.removeItem(at: url)
		//			} catch {
		//				// Handle error
		//			}
		//
		//			// write out a placeholder to facilitate future property lookups
		//			providePlaceholder(at: url, completionHandler: { _ in
		//				// TODO: handle any error, do any necessary cleanup
		//            })
		//		}
		DDLogInfo("stopProvidingItem called for: \(url)")
		guard let decorator = decorator, let identifier = persistentIdentifierForItem(at: url) else {
			return
		}
		decorator.stopProvidingItem(with: identifier, url: url, notificator: notificator).then {
			// write out a placeholder to facilitate future property lookups
			self.providePlaceholder(at: url, completionHandler: { error in
				// TODO: handle any error, do any necessary cleanup
				if let error = error {
					DDLogError("stopProvidingItem for \(url) providePlaceholder failed with: \(error)")
				} else {
					DDLogInfo("stopProvidingItem for \(url) succeeded")
				}
			})
		}.catch { error in
			DDLogError("stopProvidingItem for \(url) failed with error: \(error)")
		}
	}

	// MARK: - Actions

	/* TODO: implement the actions for items here
	 each of the actions follows the same pattern:
	 - make a note of the change in the local model
	 - schedule a server request as a background task to inform the server of the change
	 - call the completion block with the modified item in its post-modification state
	 */

	// MARK: - Enumeration

	override func enumerator(for containerItemIdentifier: NSFileProviderItemIdentifier) throws -> NSFileProviderEnumerator {
		/* let maybeEnumerator: NSFileProviderEnumerator? = nil
		 if containerItemIdentifier == NSFileProviderItemIdentifier.rootContainer {
		 	// TODO: instantiate an enumerator for the container root
		 } else if containerItemIdentifier == NSFileProviderItemIdentifier.workingSet {
		 	// TODO: instantiate an enumerator for the working set
		 } else {
		 	// TODO: determine if the item is a directory or a file
		 	// - for a directory, instantiate an enumerator of its subitems
		 	// - for a file, instantiate an enumerator that observes changes to the file
		 }
		 guard let enumerator = maybeEnumerator else {
		 	throw NSError(domain: NSCocoaErrorDomain, code: NSFeatureUnsupportedError, userInfo: [:])
		 }
		 return enumerator
		 */
		// TODO: Change error handling here
		guard let manager = self.manager, let domain = self.domain, let dbPath = dbPath, let notificator = notificator else {
			// no domain ==> no installed vault
			DDLogError("FPExtension: not initialized")
			throw NSFileProviderError(.notAuthenticated)
		}
		return FileProviderEnumerator(enumeratedItemIdentifier: containerItemIdentifier, domain: domain, manager: manager, dbPath: dbPath, notificator: notificator)
	}

	func setUp() throws {
		if let domain = self.domain {
			guard let manager = NSFileProviderManager(for: domain) else {
				throw FileProviderDecoratorSetupError.fileProviderManagerIsNil
			}
			self.manager = manager
			let dbPath = manager.documentStorageURL.appendingPathComponent(domain.pathRelativeToDocumentStorage, isDirectory: true).appendingPathComponent("db.sqlite")
			self.dbPath = dbPath
			notificator = FileProviderNotificator(manager: manager)
			DecoratorManager.getDecorator(for: domain, with: manager, dbPath: dbPath).then { decorator in
				self.decorator = decorator
			}
		} else {
			DDLogInfo("setUpDecorator called with nil domain")
			throw FileProviderDecoratorSetupError.domainIsNil
		}
	}

	override func supportedServiceSources(for itemIdentifier: NSFileProviderItemIdentifier) throws -> [NSFileProviderServiceSource] {
		var serviceSources = [NSFileProviderServiceSource]()
		#if DEBUG
		serviceSources.append(FileProviderValidationServiceSource(fileProviderExtension: self, itemIdentifier: itemIdentifier))
		#endif
		return serviceSources
	}
}

enum FileProviderDecoratorSetupError: Error {
	case fileProviderManagerIsNil
	case domainIsNil
}

extension URL {
	func appendPathComponents(from other: URL, startIndex: Int = 1) -> URL {
		precondition(startIndex > 0)
		precondition(hasDirectoryPath)
		var result = self
		let components = other.pathComponents
		for i in startIndex ..< components.count {
			let isDirectory = (i < components.count - 1 || other.hasDirectoryPath)
			result.appendPathComponent(components[i], isDirectory: isDirectory)
		}
		return result
	}
}

enum LoggerSetup {
	private static var loggerInitialized = false

	static func oneTimeSetup() {
		guard !loggerInitialized else {
			return
		}
		guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: CryptomatorConstants.appGroupName) else {
			print("containerURL is nil")
			return
		}
		let logDirectory = containerURL.appendingPathComponent("Logs")

		do {
			try FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: false, attributes: nil)
		} catch {
			print(error)
		}
		print("LogDirectory: \(logDirectory.path)")
		let logFileManager = DDLogFileManagerDefault(logsDirectory: logDirectory.path)
		let fileLogger = DDFileLogger(logFileManager: logFileManager)
		DDLog.add(DDOSLogger.sharedInstance)
		DDLog.add(fileLogger)
		loggerInitialized = true
	}
}
