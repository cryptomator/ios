//
//  FileProviderAdapter.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 04.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import Dependencies
import FileProvider
import Foundation
import UniformTypeIdentifiers

public protocol FileProviderAdapterType: AnyObject, Sendable {
	var lastUnlockedDate: Date { get }
	func item(for identifier: NSFileProviderItemIdentifier) throws -> NSFileProviderItem
	func enumerateItems(for identifier: NSFileProviderItemIdentifier, withPageToken pageToken: String?) async throws -> FileProviderItemList
	func importDocument(at fileURL: URL, toParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping @Sendable (NSFileProviderItem?, Error?) -> Void)
	func itemChanged(at url: URL)
	func createDirectory(withName directoryName: String, inParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping @Sendable (NSFileProviderItem?, Error?) -> Void)
	func stopProvidingItem(at url: URL)
	func renameItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, toName itemName: String, completionHandler: @escaping @Sendable (NSFileProviderItem?, Error?) -> Void)
	func reparentItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, toParentItemWithIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, newName: String?, completionHandler: @escaping @Sendable (NSFileProviderItem?, Error?) -> Void)
	func deleteItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping @Sendable (Error?) -> Void)
	func startProvidingItem(at url: URL, completionHandler: @escaping @Sendable (_ error: Error?) -> Void)
	func setFavoriteRank(_ favoriteRank: NSNumber?, forItemIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: (NSFileProviderItem?, Error?) -> Void)
	func setTagData(_ tagData: Data?, forItemIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: (NSFileProviderItem?, Error?) -> Void)
	func retryUpload(for itemIdentifier: NSFileProviderItemIdentifier)
	func recoverStuckUploads()
	func getItemIdentifier(for cloudPath: CloudPath) async throws -> NSFileProviderItemIdentifier
}

extension FileProviderAdapterType {
	func importDocument(at fileURL: URL, toParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier) async throws -> FileProviderItem? {
		return try await withCheckedThrowingContinuation { continuation in
			importDocument(at: fileURL, toParentItemIdentifier: parentItemIdentifier) { item, error in
				if let error = error {
					continuation.resume(throwing: error)
				} else {
					continuation.resume(returning: item as? FileProviderItem)
				}
			}
		}
	}
}

@MainActor
public final class FileProviderAdapter: FileProviderAdapterType {
	public let lastUnlockedDate: Date
	private let uploadTaskManager: UploadTaskManager
	private let cachedFileManager: CachedFileManager
	private let itemMetadataManager: ItemMetadataManager
	private let reparentTaskManager: ReparentTaskManager
	private let deletionTaskManager: DeletionTaskManager
	private let itemEnumerationTaskManager: ItemEnumerationTaskManager
	private let downloadTaskManager: DownloadTaskManager
	private let scheduler: WorkflowScheduler
	private let provider: CloudProvider
	private let localURLProvider: LocalURLProviderType
	private let notificator: FileProviderItemUpdateDelegate?
	@Dependency(\.fullVersionChecker) private var fullVersionChecker
	private let workflowFactory: WorkflowFactory
	private let domainIdentifier: NSFileProviderDomainIdentifier
	private let fileCoordinatorPurposeIdentifier: String
	private let taskRegistrator: SessionTaskRegistrator
	private let deleteItemHelper: DeleteItemHelper
	@Dependency(\.permissionProvider) private var permissionProvider
	private var workflows = [UUID: (identifier: NSFileProviderItemIdentifier?, task: Task<Void, Never>)]()

	nonisolated init(domainIdentifier: NSFileProviderDomainIdentifier,
	                 uploadTaskManager: UploadTaskManager,
	                 cachedFileManager: CachedFileManager,
	                 itemMetadataManager: ItemMetadataManager,
	                 reparentTaskManager: ReparentTaskManager,
	                 deletionTaskManager: DeletionTaskManager,
	                 itemEnumerationTaskManager: ItemEnumerationTaskManager,
	                 downloadTaskManager: DownloadTaskManager,
	                 scheduler: WorkflowScheduler,
	                 maxParallelUploads: Int,
	                 maxParallelDownloads: Int,
	                 provider: CloudProvider,
	                 fileCoordinatorPurposeIdentifier: String,
	                 notificator: FileProviderItemUpdateDelegate? = nil,
	                 localURLProvider: LocalURLProviderType,
	                 taskRegistrator: SessionTaskRegistrator) {
		self.lastUnlockedDate = Date()
		self.domainIdentifier = domainIdentifier
		self.uploadTaskManager = uploadTaskManager
		self.cachedFileManager = cachedFileManager
		self.itemMetadataManager = itemMetadataManager
		self.reparentTaskManager = reparentTaskManager
		self.deletionTaskManager = deletionTaskManager
		self.itemEnumerationTaskManager = itemEnumerationTaskManager
		self.downloadTaskManager = downloadTaskManager
		self.deleteItemHelper = DeleteItemHelper(itemMetadataManager: itemMetadataManager, cachedFileManager: cachedFileManager)
		self.workflowFactory = WorkflowFactory(provider: provider,
		                                       uploadTaskManager: uploadTaskManager,
		                                       cachedFileManager: cachedFileManager,
		                                       itemMetadataManager: itemMetadataManager,
		                                       reparentTaskManager: reparentTaskManager,
		                                       deletionTaskManager: deletionTaskManager,
		                                       itemEnumerationTaskManager: itemEnumerationTaskManager,
		                                       downloadTaskManager: downloadTaskManager,
		                                       maxParallelUploads: maxParallelUploads,
		                                       maxParallelDownloads: maxParallelDownloads,
		                                       domainIdentifier: domainIdentifier)
		self.scheduler = scheduler
		self.provider = provider
		self.notificator = notificator
		self.localURLProvider = localURLProvider
		self.fileCoordinatorPurposeIdentifier = fileCoordinatorPurposeIdentifier
		self.taskRegistrator = taskRegistrator
	}

	/**
	 Gets the locally stored metadata for an identifier.

	 - Precondition: The passed `identifier` is a valid `identifier` and the corresponding item is stored in the database.
	 - Postcondition: If there was an upload error for the associated item, it was added to the returned `FileProviderItem`.
	 - Postcondition: If there was information about the associated local file, it was added to the returned `FileProviderItem`.
	 - Returns: `FileProviderItem` with the locally stored metadata for the passed `identifier`.
	 */
	public nonisolated func item(for identifier: NSFileProviderItemIdentifier) throws -> NSFileProviderItem {
		let itemMetadata = try getCachedMetadata(for: identifier)
		let uploadTask = try uploadTaskManager.getTaskRecord(for: itemMetadata)
		let localCachedFileInfo = try cachedFileManager.getLocalCachedFileInfo(for: itemMetadata)
		return FileProviderItem(metadata: itemMetadata, domainIdentifier: domainIdentifier, localCachedFileInfo: localCachedFileInfo, error: uploadTask?.failedWithError)
	}

	// MARK: Enumerate Item

	/**
	 Performs an enumeration on the item.

	 On a folder, this contains all items within that folder. If the `CloudProvider` supports it, only page enumeration is performed and a `pageToken` is returned.

	 If an enumeration is performed on a file, only its metadata is refreshed.

	 An enumeration on the `workingSet` always returns an empty `FileProviderItemList`.

	 This is because the contents of the working set are visible in the "Recents" tab of the Files app and could therefore also be visible when the vault is locked.

	 - Parameter identifier: The identifier of the item on which the enumeration is to be performed.
	 - Parameter pageToken: (Optional) The page token that was previously returned when this function was called with the same identifier.
	 - Precondition: The `ItemMetadata` associated with the `identifier` exists in the database.
	 - Precondition: The `itemType` of the `ItemMetadata` is either file or folder.
	 - Precondition: An authenticated `VaultDecorator` exists for the `vaultUID`.
	 - Returns: Depending on the type of item associated with the passed identifier, the following is returned:
	   - If the `identifier` is the `workingSet`: empty `FileProviderItemList`.
	   - If the `identifier` belongs to a folder: `FileProviderItemList` with children of the folder and if it was not a complete enumeration, i.e. there are more items in the folder, also a `nextPageToken`.
	   - If the `identifier` belongs to a file: `FileProviderItemList` with exactly one `FileProviderItem`, which corresponds to the `identifier`.
	 */
	@MainActor public func enumerateItems(for identifier: NSFileProviderItemIdentifier, withPageToken pageToken: String?) async throws -> FileProviderItemList {
		// TODO: Check for internet connection here
		if identifier == .workingSet {
			return try enumerateWorkingSet()
		}
		let id = try convertFileProviderItemIdentifierToInt64(identifier)
		guard let cachedItemMetadata = try itemMetadataManager.getCachedMetadata(for: id) else {
			throw CloudProviderError.itemNotFound
		}
		let enumerationTask = try itemEnumerationTaskManager.createTask(for: cachedItemMetadata, pageToken: pageToken)
		return try await run(workflowFactory.createWorkflow(for: enumerationTask), for: identifier)
	}

	private func enumerateWorkingSet() throws -> FileProviderItemList {
		let metadataList = try itemMetadataManager.getAllCachedMetadataInsideWorkingSet()
		let items = try FileProviderItem.items(from: metadataList, domainIdentifier: domainIdentifier, uploadTaskManager: uploadTaskManager, cachedFileManager: cachedFileManager)
		return FileProviderItemList(items: items, nextPageToken: nil)
	}

	// MARK: UploadFile

	public nonisolated func importDocument(at fileURL: URL, toParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping @Sendable (NSFileProviderItem?, Error?) -> Void) {
		submit {
			autoreleasepool {
				if self.isPackage(at: fileURL) {
					self.importPackage(at: fileURL, toParentItemIdentifier: parentItemIdentifier, completionHandler: completionHandler)
					return
				}
				let localItemImportResult: LocalItemImportResult
				do {
					localItemImportResult = try self.localItemImport(fileURL: fileURL, parentIdentifier: parentItemIdentifier)
				} catch let error as NSError {
					return self.reportLocalImportFailure(error, importing: fileURL, completionHandler: completionHandler)
				}
				let localImportHandler: (Error?) -> Void = { error in
					if let error = error {
						completionHandler(nil, error)
					} else {
						completionHandler(localItemImportResult.item, nil)
					}
				}
				// Network Stuff
				self.uploadFile(taskRecord: localItemImportResult.uploadTaskRecord,
				                completionHandler: localImportHandler,
				                itemIdentifier: localItemImportResult.item.itemIdentifier)
			}
		}
	}

	/// The file name and a `FileManager` error's `NSFilePath` are cleartext, and a failed import hands back no item id to log instead.
	private func reportLocalImportFailure(_ error: NSError, importing fileURL: URL, completionHandler: (NSFileProviderItem?, Error?) -> Void) {
		if error.domain == NSFileProviderErrorDomain, error.code == NSFileProviderError.filenameCollision.rawValue {
			DDLogInfo("FPExt: filenameCollision for item with extension: \(fileURL.pathExtension)")
			return completionHandler(nil, error)
		}
		DDLogError("FPExt: local import failed for item with extension: \(fileURL.pathExtension) with \(error.domain) \(error.code)")
		// Returning the underlying error instead makes the Files app render "Couldn't communicate with a helper
		// application", which says even less than `noSuchItem`.
		completionHandler(nil, NSFileProviderError(.noSuchItem))
	}

	/**
	 Imports a file locally.

	 If an error occurs while copying the file, the corresponding item will be removed from the database.
	 Because in this case the user will have to try importing the file again.

	 This import checks for local filename collisions via the CloudPath.
	 - Precondition: A file exists at the `fileURL`
	 - Precondition: There is not yet a local copy of the file located at the `fileURL`, i.e. the file is not yet in our document storage directory.
	 - Postcondition: The file was successfully copied to our document storage.
	 - Postcondition: A new `UploadTask` was created for the passed `item`.
	 - Postcondition: A `LocalCachedFileInfo` with the url of the copied file exists in the database and has as `correspondingItem` the `id` of the newly created `ItemMetadata` entry.
	 */
	func localItemImport(fileURL: URL, parentIdentifier: NSFileProviderItemIdentifier) throws -> LocalItemImportResult {
		let stopAccess = fileURL.startAccessingSecurityScopedResource()
		defer {
			if stopAccess {
				fileURL.stopAccessingSecurityScopedResource()
			}
		}
		let placeholderMetadata = try createPlaceholderItemForFile(for: fileURL, in: parentIdentifier)
		let itemIdentifier = convertIDToItemIdentifier(placeholderMetadata.id!)

		let localURL: URL
		do {
			guard let url = localURLProvider.urlForItem(withPersistentIdentifier: itemIdentifier, itemName: placeholderMetadata.name) else {
				throw NSFileProviderError(.noSuchItem)
			}
			localURL = url
			try copyItem(from: fileURL, to: localURL, itemMetadata: placeholderMetadata)
		} catch {
			// Remove the item from the database, because the local import failed and therefore the user has to start a new import.
			try itemMetadataManager.removeItemMetadata(with: placeholderMetadata.id!)
			throw error
		}

		// Register LocalURL in the DB
		try cachedFileManager.cacheLocalFileInfo(for: placeholderMetadata.id!, localURL: localURL, lastModifiedDate: nil)
		let item = FileProviderItem(metadata: placeholderMetadata, domainIdentifier: domainIdentifier, newestVersionLocallyCached: true, localURL: localURL)
		let uploadTaskRecord = try registerFileInUploadQueue(with: localURL, itemMetadata: placeholderMetadata)
		return LocalItemImportResult(item: item, uploadTaskRecord: uploadTaskRecord)
	}

	func copyItem(from sourceURL: URL, to targetURL: URL, itemMetadata: ItemMetadata) throws {
		var fileManagerError: NSError?
		var fileCoordinatorError: NSError?
		makeFileCoordinator().coordinate(readingItemAt: sourceURL, options: .withoutChanges, error: &fileCoordinatorError) { _ in
			do {
				try FileManager.default.createDirectory(at: targetURL.deletingLastPathComponent(), withIntermediateDirectories: true)
				try FileManager.default.copyItem(at: sourceURL, to: targetURL)
			} catch let error as NSError {
				fileManagerError = error as NSError
			}
		}
		if let error = fileManagerError ?? fileCoordinatorError {
			throw error
		}
	}

	// MARK: Import Package

	/// Reading the resource value is access to the item, so it needs the security scope just like the import itself does.
	func isPackage(at url: URL) -> Bool {
		let stopAccess = url.startAccessingSecurityScopedResource()
		defer {
			if stopAccess {
				url.stopAccessingSecurityScopedResource()
			}
		}
		if let isPackage = try? url.resourceValues(forKeys: [.isPackageKey]).isPackage {
			return isPackage
		}
		// `UTType(filenameExtension:conformingTo:)` synthesizes a dynamic type when nothing declared matches, and an extension
		// cannot tell a package directory from a flat document carrying the same extension, which iWork formats do.
		guard let type = UTType(filenameExtension: url.pathExtension, conformingTo: .package), type.isDeclared else {
			return false
		}
		return (try? itemType(at: url)) == FileAttributeType.typeDirectory
	}

	/**
	 Imports a package by recursively importing its contents as an ordinary encrypted folder.

	 The package keeps its name, including the extension, so copying it back out to a regular file system reconstitutes a
	 working package.
	 */
	func importPackage(at fileURL: URL, toParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping @Sendable (NSFileProviderItem?, Error?) -> Void) {
		let result: LocalPackageImportResult
		do {
			result = try localPackageImport(fileURL: fileURL, parentIdentifier: parentItemIdentifier)
		} catch let error as NSError {
			reportLocalImportFailure(error, importing: fileURL, completionHandler: completionHandler)
			return
		}
		completionHandler(result.item, nil)
		let rootNode = result.rootNode
		// Created before the run starts, so the root registers its dependencies ahead of anything submitted after this import.
		let workflow: Workflow<FileProviderItem>
		do {
			workflow = try createPackageFolderWorkflow(for: rootNode, isRoot: true)
		} catch {
			// The item exists in the vault by now, so log its id rather than its cleartext name.
			DDLogError("importPackage failed for item \(rootNode.itemMetadata.id ?? -1) with error: \(error)")
			return
		}
		start(for: result.item.itemIdentifier) {
			do {
				try await self.runPackageFolder(workflow, for: rootNode)
			} catch {
				DDLogError("importPackage failed for item \(rootNode.itemMetadata.id ?? -1) with error: \(error)")
			}
		}
	}

	/**
	 Imports a package locally, depth-first.

	 - Precondition: A package exists at the `fileURL`.
	 - Postcondition: No `UploadTaskRecord` was created, so a stuck upload recovery cannot upload into a package root that does not exist yet.
	 - Postcondition: If anything failed, the whole subtree was removed again, because the completion handler has not reported success yet.
	 */
	func localPackageImport(fileURL: URL, parentIdentifier: NSFileProviderItemIdentifier) throws -> LocalPackageImportResult {
		// Held across the whole walk, not just a single copy, because every descendant is read through this scope.
		let stopAccess = fileURL.startAccessingSecurityScopedResource()
		defer {
			if stopAccess {
				fileURL.stopAccessingSecurityScopedResource()
			}
		}
		let parentID = try convertFileProviderItemIdentifierToInt64(parentIdentifier)
		let name = fileURL.lastPathComponent.precomposedStringWithCanonicalMapping
		let cloudPath = try getCloudPathForPlaceholderItem(withName: name, in: parentID, type: .folder)
		// Stricter than `checkLocalItemCollision`, which treats a pending deletion as free: that deletion would complete later
		// and take the freshly imported package with it.
		if let existingItemMetadata = try itemMetadataManager.getCachedMetadata(for: cloudPath) {
			throw NSError.fileProviderErrorForCollision(with: FileProviderItem(metadata: existingItemMetadata, domainIdentifier: domainIdentifier))
		}
		let rootItem = try createPlaceholderItemForFolder(withName: name, in: parentIdentifier)
		do {
			let rootIdentifier = convertIDToItemIdentifier(rootItem.metadata.id!)
			let children = try coordinatedPackageContents(of: fileURL, into: rootIdentifier)
			// A fresh instance, because the folder creation mutates it while fileproviderd may still read the returned item.
			let rootNode = try ImportedPackageNode(itemMetadata: getCachedMetadata(for: rootIdentifier), localURL: nil, children: children)
			return LocalPackageImportResult(item: rootItem, rootNode: rootNode)
		} catch {
			rollBackPackageImport(rootMetadata: rootItem.metadata)
			throw error
		}
	}

	/**
	 Walks the package inside a single coordinated read.

	 File coordination treats a package as one unit, so reserving each interior file separately would let a writer commit
	 between two of them and leave a copy whose files come from different revisions of the package.
	 */
	private func coordinatedPackageContents(of packageURL: URL, into parentIdentifier: NSFileProviderItemIdentifier) throws -> [ImportedPackageNode] {
		var children: [ImportedPackageNode]?
		var walkError: Error?
		var fileCoordinatorError: NSError?
		makeFileCoordinator().coordinate(readingItemAt: packageURL, options: .withoutChanges, error: &fileCoordinatorError) { url in
			do {
				try rejectSymbolicLink(itemType(at: url))
				children = try importPackageContents(of: url, into: parentIdentifier)
			} catch {
				walkError = error
			}
		}
		if let error = walkError ?? fileCoordinatorError {
			throw error
		}
		guard let children = children else {
			throw NSFileProviderError(.noSuchItem)
		}
		return children
	}

	/// Does not traverse links, so a symbolic link reports its own type here rather than its target's.
	private func itemType(at url: URL) throws -> FileAttributeType? {
		let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
		return attributes[FileAttributeKey.type] as? FileAttributeType
	}

	/**
	 Rejects a symbolic link before it is walked or copied.

	 A relative link copied into an isolated item directory has no valid target, and a directory link can escape the package or
	 form a cycle. Every directory needs this immediately before its own read, root included, because `contentsOfDirectory`
	 resolves a link and would otherwise walk whatever it points at.
	 */
	private func rejectSymbolicLink(_ type: FileAttributeType?) throws {
		if type == FileAttributeType.typeSymbolicLink {
			throw FileProviderAdapterError.symbolicLinkNotSupported
		}
	}

	private func importPackageContents(of directoryURL: URL, into parentIdentifier: NSFileProviderItemIdentifier) throws -> [ImportedPackageNode] {
		// Does not report AppleDouble sidecars (`._name`), so a package that carries them loses them on import.
		let names = try FileManager.default.contentsOfDirectory(atPath: directoryURL.path)
		return try names.sorted().map { name in
			let childURL = directoryURL.appendingPathComponent(name)
			let childType = try itemType(at: childURL)
			try rejectSymbolicLink(childType)
			switch childType {
			case FileAttributeType.typeDirectory:
				let folderItem = try createPlaceholderItemForFolder(withName: name, in: parentIdentifier)
				let children = try importPackageContents(of: childURL, into: convertIDToItemIdentifier(folderItem.metadata.id!))
				return ImportedPackageNode(itemMetadata: folderItem.metadata, localURL: nil, children: children)
			default:
				let fileMetadata = try createPlaceholderItemForFile(for: childURL, in: parentIdentifier)
				let localURL = try copyPackageFile(from: childURL, itemMetadata: fileMetadata)
				return ImportedPackageNode(itemMetadata: fileMetadata, localURL: localURL, children: [])
			}
		}
	}

	private func copyPackageFile(from sourceURL: URL, itemMetadata: ItemMetadata) throws -> URL {
		let itemIdentifier = convertIDToItemIdentifier(itemMetadata.id!)
		guard let localURL = localURLProvider.urlForItem(withPersistentIdentifier: itemIdentifier, itemName: itemMetadata.name) else {
			throw NSFileProviderError(.noSuchItem)
		}
		// Uncoordinated on purpose: the whole walk already runs inside one coordinated read of the package root, and taking a
		// second reservation per file is what would let a writer tear the copy apart.
		try FileManager.default.createDirectory(at: localURL.deletingLastPathComponent(), withIntermediateDirectories: true)
		try FileManager.default.copyItem(at: sourceURL, to: localURL)
		do {
			try cachedFileManager.cacheLocalFileInfo(for: itemMetadata.id!, localURL: localURL, lastModifiedDate: nil)
		} catch {
			// The rollback finds copied bytes through their `LocalCachedFileInfo`, so without that row it would leave the
			// cleartext behind. Nothing else ever reclaims it.
			do {
				try FileManager.default.removeItem(at: localURL)
			} catch let removalError as NSError {
				// Only domain and code: a `FileManager` error carries `NSFilePath`, which would put the item's cleartext name
				// into a log the user can export.
				DDLogError("Package import: cleartext left behind for item \(itemMetadata.id ?? -1), removal failed with \(removalError.domain) \(removalError.code)")
			}
			throw error
		}
		return localURL
	}

	/**
	 Removes a partially imported package again.

	 Only correct before the completion handler reported success. Afterwards the local copies may be all the user has left,
	 because the Files app removes the source of a move as soon as the import returns.
	 */
	private func rollBackPackageImport(rootMetadata: ItemMetadata) {
		do {
			try deleteItemHelper.removeItemFromCache(rootMetadata)
		} catch let error as NSError {
			// Domain and code only, because a `FileManager` error names the path it failed on.
			DDLogError("Package import: removing cached files during rollback failed with \(error.domain) \(error.code)")
		}
		do {
			// Descendants go with it, because `itemMetadata.parentID` cascades. Attempted even when the cache removal failed,
			// though it can only succeed once every `cachedFiles` row is gone — that table has no cascade rule.
			try itemMetadataManager.removeItemMetadata(with: rootMetadata.id!)
		} catch {
			DDLogError("Package import: removing metadata during rollback failed with error: \(error)")
		}
	}

	func schedulePackageFolder(_ node: ImportedPackageNode, isRoot: Bool) async throws {
		try await runPackageFolder(createPackageFolderWorkflow(for: node, isRoot: isRoot), for: node)
	}

	private func createPackageFolderWorkflow(for node: ImportedPackageNode, isRoot: Bool) throws -> Workflow<FileProviderItem> {
		do {
			let cloudPath = try itemMetadataManager.getCloudPath(for: node.itemMetadata.id!)
			let task = FolderCreationTask(itemMetadata: node.itemMetadata, cloudPath: cloudPath, onlineCollisionDisposition: isRoot ? .renameAndRetry : .fail)
			return workflowFactory.createWorkflow(for: task)
		} catch {
			DDLogError("Package import: building the task for folder \(node.itemMetadata.id ?? -1) failed with error: \(error)")
			markPackageSubtreeAsUploadError(node, error: error)
			throw error
		}
	}

	/**
	 Creates a package folder in the cloud and only then constructs and schedules everything below it.

	 The dependency graph alone would not hold them back, because it releases dependents even when the parent failed.
	 */
	private func runPackageFolder(_ workflow: Workflow<FileProviderItem>, for node: ImportedPackageNode) async throws {
		let item: FileProviderItem
		do {
			item = try await run(workflow, for: convertIDToItemIdentifier(node.itemMetadata.id!))
		} catch {
			DDLogError("Package import: creating folder \(node.itemMetadata.id ?? -1) failed with error: \(error)")
			markPackageSubtreeAsUploadError(node, error: error)
			throw error
		}
		notificator?.signalUpdate(for: item)
		await schedulePackageChildren(of: node)
	}

	/// Sibling subtrees are independent, so one failing child neither cancels nor fails the others.
	private func schedulePackageChildren(of node: ImportedPackageNode) async {
		let scheduledChildren = node.children.map { child in
			Task { @MainActor in
				if child.itemMetadata.type == .folder {
					try? await self.schedulePackageFolder(child, isRoot: false)
				} else {
					try? await self.schedulePackageFileUpload(child)
				}
			}
		}
		for scheduledChild in scheduledChildren {
			await scheduledChild.value
		}
	}

	/// Marks the descendants too, because nothing schedules them once their folder failed.
	private func markPackageSubtreeAsUploadError(_ node: ImportedPackageNode, error: Error) {
		if node.itemMetadata.type == .folder {
			markPackageFolderAsUploadError(node.itemMetadata, error: error)
		} else {
			markPackageFileAsUploadError(node.itemMetadata)
		}
		for child in node.children {
			markPackageSubtreeAsUploadError(child, error: error)
		}
	}

	/// `markUploadAsError` cannot be used, because it creates an `UploadTaskRecord`, which only a file may have.
	private func markPackageFolderAsUploadError(_ itemMetadata: ItemMetadata, error: Error) {
		do {
			itemMetadata.statusCode = .uploadError
			try itemMetadataManager.updateMetadata(itemMetadata)
			let item = FileProviderItem(metadata: itemMetadata, domainIdentifier: domainIdentifier, error: error)
			notificator?.signalUpdate(for: item)
		} catch {
			DDLogError("Package import: marking folder \(itemMetadata.id ?? -1) as failed itself failed with error: \(error)")
		}
	}

	private func markPackageFileAsUploadError(_ itemMetadata: ItemMetadata) {
		do {
			try markUploadAsError(itemMetadata)
		} catch {
			DDLogError("Package import: marking item \(itemMetadata.id ?? -1) as failed itself failed with error: \(error)")
		}
	}

	private func schedulePackageFileUpload(_ node: ImportedPackageNode) async throws {
		let itemIdentifier = convertIDToItemIdentifier(node.itemMetadata.id!)
		let taskRecord: UploadTaskRecord
		do {
			guard let localURL = node.localURL else {
				throw NSFileProviderError(.noSuchItem)
			}
			taskRecord = try registerFileInUploadQueue(with: localURL, itemMetadata: node.itemMetadata)
		} catch {
			DDLogError("Package import: registering item \(node.itemMetadata.id ?? -1) for upload failed with error: \(error)")
			markPackageFileAsUploadError(node.itemMetadata)
			throw error
		}
		let item: FileProviderItem
		do {
			item = try await run(createUploadWorkflow(taskRecord: taskRecord, itemIdentifier: itemIdentifier), for: itemIdentifier)
		} catch {
			// The upload executor records every failure it catches and returns an error-bearing item instead, so a thrown error is one nothing has recorded.
			// Domain and code only, because a `FileManager` error names the path it failed on.
			let error = error as NSError
			DDLogError("Package import: uploading item \(node.itemMetadata.id ?? -1) failed with \(error.domain) \(error.code)")
			markPackageFileAsUploadError(node.itemMetadata)
			throw error
		}
		notificator?.signalUpdate(for: item)
		// The upload executor catches provider errors internally and returns an error-bearing item, so a collision only
		// becomes visible here. Nothing was renamed, which is why inspecting it after the fact is still in time.
		guard let error = item.uploadingError as NSError?, error.domain == NSFileProviderErrorDomain,
		      error.code == NSFileProviderError.filenameCollision.rawValue else {
			return
		}
		DDLogError("Package import: item \(node.itemMetadata.id ?? -1) collided with an existing item, not retrying")
		throw error
	}

	/**
	 Tells the File Provider adapter that a document has changed.

	 */
	public nonisolated func itemChanged(at url: URL) {
		guard let itemIdentifier = localURLProvider.persistentIdentifierForItem(at: url) else {
			DDLogError("itemChanged - no persistentIdentifier for item")
			return
		}
		let uploadTaskRecord: UploadTaskRecord
		do {
			let itemMetadata = try getCachedMetadata(for: itemIdentifier)
			uploadTaskRecord = try registerFileInUploadQueue(with: url, itemMetadata: itemMetadata)
		} catch {
			DDLogError("itemChanged - register file in upload queue for identifier: \(itemIdentifier) failed with error: \(error)")
			return
		}
		submit {
			self.uploadFile(taskRecord: uploadTaskRecord, itemIdentifier: itemIdentifier)
		}
	}

	public nonisolated func retryUpload(for itemIdentifier: NSFileProviderItemIdentifier) {
		let itemMetadata: ItemMetadata
		let localCachedFileInfo: LocalCachedFileInfo
		let uploadTaskRecord: UploadTaskRecord
		do {
			itemMetadata = try getCachedMetadata(for: itemIdentifier)
			guard let cachedFileInfo = try cachedFileManager.getLocalCachedFileInfo(for: itemMetadata) else {
				DDLogError("retryUpload - no local cached file info for identifier: \(itemIdentifier)")
				return
			}
			localCachedFileInfo = cachedFileInfo
			uploadTaskRecord = try registerFileInUploadQueue(with: localCachedFileInfo.localURL, itemMetadata: itemMetadata)
		} catch {
			DDLogError("retryUpload - failed for identifier: \(itemIdentifier) with error: \(error)")
			return
		}
		let item = FileProviderItem(metadata: itemMetadata, domainIdentifier: domainIdentifier, localCachedFileInfo: localCachedFileInfo)
		notificator?.signalUpdate(for: item)
		submit {
			self.uploadFile(taskRecord: uploadTaskRecord, itemIdentifier: itemIdentifier)
		}
	}

	public nonisolated func recoverStuckUploads() {
		recoverActiveUploads()
		retryConnectivityFailedUploads()
	}

	private nonisolated func recoverActiveUploads() {
		let activeTaskRecords: [UploadTaskRecord]
		do {
			activeTaskRecords = try uploadTaskManager.getActiveUploadTaskRecords()
		} catch {
			DDLogError("recoverActiveUploads - failed to get active upload task records: \(error)")
			return
		}
		guard !activeTaskRecords.isEmpty else {
			return
		}
		DDLogInfo("recoverActiveUploads - found \(activeTaskRecords.count) stuck upload(s), attempting recovery")
		for taskRecord in activeTaskRecords {
			rescheduleUpload(for: taskRecord)
		}
	}

	private nonisolated func retryConnectivityFailedUploads() {
		let retryableTaskRecords: [UploadTaskRecord]
		do {
			retryableTaskRecords = try uploadTaskManager.getRetryableUploadTaskRecords()
		} catch {
			DDLogError("retryConnectivityFailedUploads - failed to get retryable upload task records: \(error)")
			return
		}
		guard !retryableTaskRecords.isEmpty else {
			return
		}
		DDLogInfo("retryConnectivityFailedUploads - found \(retryableTaskRecords.count) connectivity-failed upload(s), retrying")
		for taskRecord in retryableTaskRecords {
			rescheduleUpload(for: taskRecord)
		}
	}

	private nonisolated func rescheduleUpload(for taskRecord: UploadTaskRecord) {
		let itemID = taskRecord.correspondingItem
		do {
			guard let itemMetadata = try itemMetadataManager.getCachedMetadata(for: itemID) else {
				DDLogInfo("rescheduleUpload - no metadata for item \(itemID), removing orphaned task record")
				try uploadTaskManager.removeTaskRecord(for: itemID)
				return
			}
			guard let localCachedFileInfo = try cachedFileManager.getLocalCachedFileInfo(for: itemID) else {
				DDLogInfo("rescheduleUpload - no local cached file for item \(itemID), marking as error")
				try markUploadAsError(itemMetadata)
				return
			}
			guard FileManager.default.fileExists(atPath: localCachedFileInfo.localURL.path) else {
				DDLogInfo("rescheduleUpload - local file missing for item \(itemID), marking as error")
				try markUploadAsError(itemMetadata)
				return
			}
			DDLogInfo("rescheduleUpload - re-scheduling upload for item \(itemID)")
			let newTaskRecord = try registerFileInUploadQueue(with: localCachedFileInfo.localURL, itemMetadata: itemMetadata)
			let itemIdentifier = NSFileProviderItemIdentifier(domainIdentifier: domainIdentifier, itemID: itemID)
			submit {
				self.uploadFile(taskRecord: newTaskRecord, itemIdentifier: itemIdentifier)
			}
		} catch {
			DDLogError("rescheduleUpload - failed for item \(itemID): \(error)")
		}
	}

	/// Creates the task record if the upload failed before it existed, because re-enumeration rebuilds the error from the record alone.
	private nonisolated func markUploadAsError(_ itemMetadata: ItemMetadata) throws {
		let error = NSFileProviderError(.noSuchItem) as NSError
		if try uploadTaskManager.getTaskRecord(for: itemMetadata) == nil {
			_ = try uploadTaskManager.createNewTaskRecord(for: itemMetadata)
		}
		try uploadTaskManager.updateTaskRecord(for: itemMetadata, with: error)
		itemMetadata.statusCode = .uploadError
		try itemMetadataManager.updateMetadata(itemMetadata)
		let item = FileProviderItem(metadata: itemMetadata, domainIdentifier: domainIdentifier, error: error)
		notificator?.signalUpdate(for: item)
	}

	/// Reports to `completionHandler` once the workflow is created and before it runs, so the upload's outcome never reaches it.
	func uploadFile(taskRecord: UploadTaskRecord, completionHandler: ((Error?) -> Void)? = nil, itemIdentifier: NSFileProviderItemIdentifier) {
		let workflow: Workflow<FileProviderItem>
		do {
			workflow = try createUploadWorkflow(taskRecord: taskRecord, itemIdentifier: itemIdentifier)
		} catch {
			completionHandler?(error)
			return
		}
		completionHandler?(nil)
		startWorkflow(workflow, for: itemIdentifier)
	}

	private func createUploadWorkflow(taskRecord: UploadTaskRecord, itemIdentifier: NSFileProviderItemIdentifier) throws -> Workflow<FileProviderItem> {
		let task = try uploadTaskManager.getTask(for: taskRecord, onURLSessionTaskCreation: makeTaskRegistrationHook(for: itemIdentifier, taskName: "URLSessionUploadTask"))
		return workflowFactory.createWorkflow(for: task)
	}

	nonisolated func registerFileInUploadQueue(with localURL: URL, itemMetadata: ItemMetadata) throws -> UploadTaskRecord {
		precondition(localURL.isFileURL)
		precondition(itemMetadata.type == .file)

		itemMetadata.statusCode = ItemStatus.isUploading
		let uploadTaskRecord: UploadTaskRecord
		do {
			let lastModifiedDate = try lastModifiedDateOfItem(at: localURL)
			try itemMetadataManager.updateMetadata(itemMetadata)
			try uploadTaskManager.removeTaskRecord(for: itemMetadata)
			uploadTaskRecord = try uploadTaskManager.createNewTaskRecord(for: itemMetadata)
			try cachedFileManager.cacheLocalFileInfo(for: itemMetadata.id!, localURL: localURL, lastModifiedDate: lastModifiedDate)
		} catch let error as NSError {
			// Domain and code only, because a `FileManager` error names the path it failed on.
			DDLogError("Register file in upload queue for item \(itemMetadata.id ?? -1) failed with \(error.domain) \(error.code)")
			throw NSFileProviderError(.noSuchItem)
		}
		return uploadTaskRecord
	}

	private nonisolated func lastModifiedDateOfItem(at url: URL) throws -> Date? {
		var fileManagerError: NSError?
		var fileCoordinatorError: NSError?
		var lastModifiedDate: Date?
		makeFileCoordinator().coordinate(readingItemAt: url, options: .withoutChanges, error: &fileCoordinatorError) { _ in
			do {
				let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
				lastModifiedDate = attributes[FileAttributeKey.modificationDate] as? Date
			} catch let error as NSError {
				fileManagerError = error as NSError
			}
		}
		if let error = fileManagerError ?? fileCoordinatorError {
			throw error
		}
		return lastModifiedDate
	}

	// MARK: Create Directory

	public nonisolated func createDirectory(withName directoryName: String, inParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping @Sendable (NSFileProviderItem?, Error?) -> Void) {
		submit {
			let placeholderItem: FileProviderItem
			do {
				placeholderItem = try self.createPlaceholderItemForFolder(withName: directoryName, in: parentItemIdentifier)
			} catch {
				DDLogError("Create directory: createPlaceholderItemForFolder failed with error: \(error) ")
				return completionHandler(nil, error)
			}

			let task: FolderCreationTask
			do {
				let cloudPath = try self.itemMetadataManager.getCloudPath(for: placeholderItem.metadata.id!)
				// A fresh instance, because the folder creation mutates it while fileproviderd may still read the placeholder item.
				task = try FolderCreationTask(itemMetadata: self.getCachedMetadata(for: placeholderItem.itemIdentifier), cloudPath: cloudPath)
			} catch {
				DDLogError("Create directory: getCloudPath failed with error: \(error)")
				return completionHandler(nil, error)
			}
			let workflow = self.workflowFactory.createWorkflow(for: task)
			completionHandler(placeholderItem, nil)
			self.startWorkflow(workflow, for: placeholderItem.itemIdentifier)
		}
	}

	// MARK: Move Item

	public nonisolated func renameItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, toName itemName: String, completionHandler: @escaping @Sendable (NSFileProviderItem?, Error?) -> Void) {
		submit {
			let result: MoveItemLocallyResult
			do {
				result = try self.moveItemLocally(withIdentifier: itemIdentifier, toParentItemWithIdentifier: nil, newName: itemName)
			} catch {
				return completionHandler(nil, error)
			}

			let reparentTask: ReparentTask
			do {
				reparentTask = try self.reparentTaskManager.getTask(for: result.reparentTaskRecord)
			} catch {
				return completionHandler(nil, error)
			}
			let workflow = self.workflowFactory.createWorkflow(for: reparentTask)
			completionHandler(result.item, nil)
			self.startWorkflow(workflow, for: itemIdentifier)
		}
	}

	public nonisolated func reparentItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, toParentItemWithIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, newName: String?, completionHandler: @escaping @Sendable (NSFileProviderItem?, Error?) -> Void) {
		submit {
			let result: MoveItemLocallyResult
			do {
				result = try self.moveItemLocally(withIdentifier: itemIdentifier, toParentItemWithIdentifier: parentItemIdentifier, newName: newName)
			} catch {
				return completionHandler(nil, error)
			}

			let reparentTask: ReparentTask
			do {
				reparentTask = try self.reparentTaskManager.getTask(for: result.reparentTaskRecord)
			} catch {
				return completionHandler(nil, error)
			}
			completionHandler(result.item, nil)
			self.startWorkflow(self.workflowFactory.createWorkflow(for: reparentTask), for: itemIdentifier)
		}
	}

	/**
	 Moves the item only locally.

	 The move only takes place in the database and the file is not moved or renamed on the local file system.

	 This ensures that previously triggered uploads, that are currently pending, do not use the wrong local URL.

	 In addition, the exact name of the item via the local URL is not further relevant (for us), since we determine the names of the items via the database.

	 - Precondition: The metadata associated with the `itemIdentifier` is stored in the database.
	 - Precondition: `parentItemIdentifier != nil || newName != nil`.
	 - Postcondition: `newName != nil` implies that the `ItemMetadata` entry in the database has the `name == newName`.
	 - Postcondition: `parentItemIdentifier != nil` implies that now the `ItemMetadata` entry in the database has the `parentID == parentItemIdentifier`.
	 - Postcondition: A `ReparentTask` was created for the passed `itemIdentifier`.
	 */
	func moveItemLocally(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, toParentItemWithIdentifier parentItemIdentifier: NSFileProviderItemIdentifier?, newName: String?) throws -> MoveItemLocallyResult {
		precondition(parentItemIdentifier != nil || newName != nil)
		let itemMetadata = try getCachedMetadata(for: itemIdentifier)
		let parentID: Int64
		if let parentItemIdentifier = parentItemIdentifier {
			parentID = try convertFileProviderItemIdentifierToInt64(parentItemIdentifier)
		} else {
			parentID = itemMetadata.parentID
		}
		let name: String
		if let newName = newName {
			try validateItemName(newName)
			// Normalize to NFC — iOS URLs use NFD, and SQLite compares bytes, not Unicode equivalence.
			name = newName.precomposedStringWithCanonicalMapping
		} else {
			name = itemMetadata.name
		}

		let sourceCloudPath = try itemMetadataManager.getCloudPath(for: itemMetadata.id!)
		let targetCloudPath = try getCloudPathForPlaceholderItem(withName: name, in: parentID, type: itemMetadata.type)
		try checkLocalItemCollision(for: targetCloudPath)
		let taskRecord = try reparentTaskManager.createTaskRecord(for: itemMetadata, sourceCloudPath: sourceCloudPath, targetCloudPath: targetCloudPath, newParentID: parentID)

		itemMetadata.name = name
		itemMetadata.parentID = parentID
		itemMetadata.statusCode = .isUploading
		try itemMetadataManager.updateMetadata(itemMetadata)

		let localCachedFileInfo = try cachedFileManager.getLocalCachedFileInfo(for: itemMetadata)
		let item = FileProviderItem(metadata: itemMetadata, domainIdentifier: domainIdentifier, localCachedFileInfo: localCachedFileInfo)
		return MoveItemLocallyResult(item: item, reparentTaskRecord: taskRecord)
	}

	func validateItemName(_ name: String) throws {
		do {
			try ItemNameValidator.validateName(name)
		} catch let error as ItemNameValidatorError {
			throw CocoaError(.fileWriteInvalidFileName, userInfo: [NSLocalizedDescriptionKey: error.localizedDescription, NSLocalizedFailureReasonErrorKey: ""])
		}
	}

	// MARK: Delete Item

	public nonisolated func deleteItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping @Sendable (Error?) -> Void) {
		submit {
			let taskRecord: DeletionTaskRecord
			do {
				taskRecord = try self.deleteItemLocally(withIdentifier: itemIdentifier)
			} catch let error as NSError {
				if error.domain == NSFileProviderErrorDomain, error.code == NSFileProviderError.noSuchItem.rawValue {
					DDLogInfo("Delete Item called for nonexistent item")
					completionHandler(nil)
					return
				}
				completionHandler(error)
				return
			}
			let deletionTask: DeletionTask
			do {
				deletionTask = try self.deletionTaskManager.getTask(for: taskRecord)
			} catch {
				completionHandler(error)
				return
			}
			let workflow = self.workflowFactory.createWorkflow(for: deletionTask)
			completionHandler(nil)
			self.start(for: itemIdentifier) {
				do {
					try await self.scheduler.schedule(workflow)
					DDLogVerbose("DeleteItem success")
				} catch {
					let error = error as NSError
					DDLogError("DeleteItem failed with \(error.domain) \(error.code)")
				}
			}
		}
	}

	/**
	 Deletes the item locally.

	 Deletes the corresponding `ItemMetadata` entry and all child items from the database and if the respective item was cached locally also from the local file system.

	 If there is no `ItemMetadata` entry for the passed `itemIdentifier` in the database, no error will be thrown.

	 This ensures that this item will be removed from the UI of the Files app anyway.

	 - Postcondition: A `DeletionTask` was created for the passed `itemIdentifier`.
	 - Postcondition: The `ItemMetadata` entry for the passed `itemIdentifier` and all `ItemMetadata` entries that have this entry as implicit parent were removed from the database and the associated locally cached files were removed from the file system.
	 */
	func deleteItemLocally(withIdentifier itemIdentifier: NSFileProviderItemIdentifier) throws -> DeletionTaskRecord {
		let itemMetadata = try getCachedMetadata(for: itemIdentifier)
		// Resolve the cloud path BEFORE removeItemFromCache deletes the row — afterwards the resolver would fail.
		let cloudPath = try itemMetadataManager.getCloudPath(for: itemMetadata.id!)
		try deleteItemHelper.removeItemFromCache(itemMetadata)
		return try deletionTaskManager.createTaskRecord(for: itemMetadata, cloudPath: cloudPath)
	}

	// MARK: Start Providing Item

	/**
	 Ensures that the actual file is at the position specified by `URLForItemWithPersistentIdentifier:`.

	 The file is immutable unless the full version of Cryptomator has been unlocked. Otherwise, it would still be possible to edit the file locally with a third-party app.
	 */
	public nonisolated func startProvidingItem(at url: URL, completionHandler: @escaping @Sendable (_ error: Error?) -> Void) {
		submit {
			let identifier: NSFileProviderItemIdentifier
			let downloadWorkflow: Workflow<FileProviderItem>?
			do {
				guard let persistentIdentifier = self.localURLProvider.persistentIdentifierForItem(at: url) else {
					throw NSFileProviderError(.noSuchItem)
				}
				identifier = persistentIdentifier
				// Created before the run starts, so the download captures the cloud path and registers its dependencies ahead of anything submitted after it.
				downloadWorkflow = FileManager.default.fileExists(atPath: url.path) ? nil : try self.createDownloadWorkflow(with: identifier, to: url)
			} catch {
				completionHandler(error)
				return
			}
			self.start(for: identifier) {
				do {
					if let downloadWorkflow = downloadWorkflow {
						try await self.runDownload(downloadWorkflow, for: identifier)
					} else {
						try await self.startProvidingItemWithLocalFile(identifier: identifier, url: url)
					}
					try self.postProcessStartProvidingItem(at: url)
					completionHandler(nil)
				} catch {
					completionHandler(error)
				}
			}
		}
	}

	func startProvidingItemWithLocalFile(identifier: NSFileProviderItemIdentifier, url: URL) async throws {
		let isCurrent = try await localFileIsCurrent(with: identifier)
		if !isCurrent {
			try await startProvidingItemWithOutdatedLocalFile(identifier: identifier, url: url)
		}
	}

	func startProvidingItemWithOutdatedLocalFile(identifier: NSFileProviderItemIdentifier, url: URL) async throws {
		let hasVersioningConflict = try hasPossibleVersioningConflictForItem(withIdentifier: identifier)
		try FileManager.default.setAttributes([.immutable: false], ofItemAtPath: url.path)
		if hasVersioningConflict {
			try await startProvidingItemWithVersioningConflict(identifier: identifier, url: url)
		} else {
			try await downloadFile(with: identifier, to: url, replaceExisting: true)
		}
	}

	func startProvidingItemWithVersioningConflict(identifier: NSFileProviderItemIdentifier, url: URL) async throws {
		let tmpDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		let tmpFileURL = tmpDirectory.appendingPathComponent(url.lastPathComponent).createCollisionURL()
		try FileManager.default.createDirectory(at: tmpDirectory, withIntermediateDirectories: false, attributes: nil)
		try FileManager.default.moveItem(at: url, to: tmpFileURL)
		let parentItemIdentifier = try item(for: identifier).parentItemIdentifier
		_ = try await importDocument(at: tmpFileURL, toParentItemIdentifier: parentItemIdentifier)
		try FileManager.default.removeItem(at: tmpDirectory)
		let itemID = try convertFileProviderItemIdentifierToInt64(identifier)
		try uploadTaskManager.removeTaskRecord(for: itemID)
		try await downloadFile(with: identifier, to: url, replaceExisting: false)
	}

	/**
	 Checks if an item has a possible versioning conflict.

	 A possible version conflict between the local file and the file in the cloud can occur if the changes to the local file have not yet been synchronized to the cloud due to an upload error and the file in the cloud has also been changed.

	 A possible conflict can also occur if the file is being uploaded and could be overwritten due to an immediate download.

	 - Precondition: `itemIdentifier.rawValue` can be cast to a positive `Int64` value.
	 - Precondition: The metadata associated with the `itemIdentifier` is stored in the database.
	 */
	func hasPossibleVersioningConflictForItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier) throws -> Bool {
		let id = try convertFileProviderItemIdentifierToInt64(itemIdentifier)
		guard let uploadTask = try uploadTaskManager.getTaskRecord(for: id) else {
			return false
		}
		let cachedLocalFileInfo = try cachedFileManager.getLocalCachedFileInfo(for: id)
		guard let localLastModifiedDate = cachedLocalFileInfo?.localLastModifiedDate else {
			return false
		}
		guard let lastFailedUploadDate = uploadTask.lastFailedUploadDate else {
			return true
		}
		return lastFailedUploadDate > localLastModifiedDate
	}

	/**
	 Checks if the local file is still up-to-date compared to the file in the cloud.

	 For performance reasons, it should be ensured, before the call, that the local file exists for which this check is performed.

	 Only the change of the `lastModifiedDate` in the cloud is checked.

	 If a cloud shows inconsistency here (e.g., change of the file without change of the `lastModifiedDate`), this is not taken into account, although it might be possible with an additional comparison of the file size.

	 - Returns:
	   - `true` if the local file is still guaranteed to be the current one or we have no internet connection.
	   - `false` if the file in the cloud is a newer version or the cloud did not return a `lastModifiedDate` or there is no `localCachedFileInfo` for the passed `identifier`.
	 */
	func localFileIsCurrent(with identifier: NSFileProviderItemIdentifier) async throws -> Bool {
		let itemMetadata = try getCachedMetadata(for: identifier)
		if itemMetadata.statusCode == .isUploading || itemMetadata.statusCode == .uploadError {
			return true
		}
		do {
			let itemList = try await enumerateItems(for: identifier, withPageToken: nil)
			guard let item = itemList.items.first else {
				throw NSFileProviderError(.noSuchItem)
			}
			let itemMetadata = item.metadata
			guard let lastModifiedDateInCloud = itemMetadata.lastModifiedDate else {
				return false
			}
			let localCachedFileInfo = try cachedFileManager.getLocalCachedFileInfo(for: itemMetadata)
			return localCachedFileInfo?.isCurrentVersion(lastModifiedDateInCloud: lastModifiedDateInCloud) ?? false
		} catch {
			guard error.isNoInternetConnectionError else {
				throw error
			}
			return true
		}
	}

	func downloadFile(with identifier: NSFileProviderItemIdentifier, to localURL: URL, replaceExisting: Bool = false) async throws {
		try await runDownload(createDownloadWorkflow(with: identifier, to: localURL, replaceExisting: replaceExisting), for: identifier)
	}

	private func createDownloadWorkflow(with identifier: NSFileProviderItemIdentifier, to localURL: URL, replaceExisting: Bool = false) throws -> Workflow<FileProviderItem> {
		let itemMetadata = try getCachedMetadata(for: identifier)
		let task = try downloadTaskManager.createTask(for: itemMetadata, replaceExisting: replaceExisting, localURL: localURL, onURLSessionTaskCreation: makeTaskRegistrationHook(for: identifier, taskName: "URLSessionTask"))
		return workflowFactory.createWorkflow(for: task)
	}

	private func runDownload(_ workflow: Workflow<FileProviderItem>, for identifier: NSFileProviderItemIdentifier) async throws {
		let item = try await run(workflow, for: identifier)
		notificator?.signalUpdate(for: item)
	}

	/**
	 Post-processing `startProvidingitem(at:)` calls.

	 The file located at `url` is immutable unless the full version of Cryptomator has been unlocked. Otherwise, it would still be possible to edit the file locally with a third-party app.

	 The `NSFileProviderItemIdentifier` associated with the URL, gets registered for removal from the working set, which is necessary because the Files app adds it to the working set when calling `startProvidingitem(at:)`.
	 `NSFileProviderItemIdentifier` associated with an item, which should be in the working set (marked as favorite or has associated tag data), are excluded from the removal.
	 */
	func postProcessStartProvidingItem(at url: URL) throws {
		try FileManager.default.setAttributes([.immutable: !fullVersionChecker.isFullVersion], ofItemAtPath: url.path)
		guard let identifier = localURLProvider.persistentIdentifierForItem(at: url) else {
			throw NSFileProviderError(.noSuchItem)
		}
		let metadata = try getCachedMetadata(for: identifier)
		if metadata.favoriteRank == nil, metadata.tagData == nil {
			notificator?.removeItemFromWorkingSet(with: identifier)
		}
	}

	// MARK: Stop Providing Item

	public nonisolated func stopProvidingItem(at url: URL) {
		#warning("TODO: Implement stopProvidingItem logic")
	}

	// MARK: Placeholder

	/**
	 Creates a placeholder item for a file.

	 - Precondition: A file exists at the passed `localURL`.
	 - Precondition: The database does not yet contain an `ItemMetadata` entry for this file.
	 - Postcondition: An `ItemMetadata` entry exists in the database with the attributes of the local file, `isPlaceholderItem == true` and `statusCode == .isUploading`.
	 - Postcondition: A `LocalCachedFileInfo` with the `localURL` exists in the database and has as `correspondingItem` the `id` of the newly created `ItemMetadata` entry.
	 - Postcondition: The returned `FileProviderItem` has `newestVersionLocallyCached == true` and the passed `localURL` of the file.
	 */
	func createPlaceholderItemForFile(for localURL: URL, in parentIdentifier: NSFileProviderItemIdentifier) throws -> ItemMetadata {
		let parentID = try convertFileProviderItemIdentifierToInt64(parentIdentifier)
		let attributes = try FileManager.default.attributesOfItem(atPath: localURL.path)
		let size = attributes[FileAttributeKey.size] as? Int
		let typeFile = attributes[FileAttributeKey.type] as? FileAttributeType
		let lastModifiedDate = attributes[FileAttributeKey.modificationDate] as? Date
		if typeFile == FileAttributeType.typeDirectory {
			throw FileProviderAdapterError.folderUploadNotSupported
		}
		// Normalize to NFC so the collision check matches cloud-fetched (NFC) entries in the DB.
		// iOS file URLs use NFD, and SQLite compares bytes — without this, non-ASCII names bypass the collision check.
		let name = localURL.lastPathComponent.precomposedStringWithCanonicalMapping
		let cloudPath = try getCloudPathForPlaceholderItem(withName: name, in: parentID, type: .file)
		try checkLocalItemCollision(for: cloudPath)
		let placeholderMetadata = ItemMetadata(name: name, type: .file, size: size, parentID: parentID, lastModifiedDate: lastModifiedDate, statusCode: .isUploading, isPlaceholderItem: true)
		try itemMetadataManager.cacheMetadata(placeholderMetadata)
		return placeholderMetadata
	}

	/**
	 Creates a placeholder item for a folder.

	 - Precondition: The database does not yet contain an `ItemMetadata` entry for this folder.
	 - Postcondition: An `ItemMetadata` entry exists in the database with `isPlaceholderItem == true` and `statusCode == .isUploading`.
	 - Postcondition: The returned `FileProviderItem` has `newestVersionLocallyCached == true`.
	 */
	func createPlaceholderItemForFolder(withName name: String, in parentIdentifier: NSFileProviderItemIdentifier) throws -> FileProviderItem {
		let parentID = try convertFileProviderItemIdentifierToInt64(parentIdentifier)
		// Normalize to NFC so the collision check matches cloud-fetched (NFC) entries in the DB.
		// iOS file URLs use NFD, and SQLite compares bytes — without this, non-ASCII names bypass the collision check.
		let normalizedName = name.precomposedStringWithCanonicalMapping
		let cloudPath = try getCloudPathForPlaceholderItem(withName: normalizedName, in: parentID, type: .folder)
		try checkLocalItemCollision(for: cloudPath)
		let placeholderMetadata = ItemMetadata(name: normalizedName, type: .folder, size: nil, parentID: parentID, lastModifiedDate: nil, statusCode: .isUploading, isPlaceholderItem: true)
		try itemMetadataManager.cacheMetadata(placeholderMetadata)
		return FileProviderItem(metadata: placeholderMetadata, domainIdentifier: domainIdentifier, newestVersionLocallyCached: true)
	}

	/**
	 Gets the cloud path based on the item name and parent id.

	 - Precondition: The passed `parentID` must belong to an item with the type `.folder`.
	 */
	func getCloudPathForPlaceholderItem(withName name: String, in parentID: Int64, type: CloudItemType) throws -> CloudPath {
		guard let parentItemMetadata = try itemMetadataManager.getCachedMetadata(for: parentID), parentItemMetadata.type == .folder else {
			throw FileProviderAdapterError.parentFolderNotFound
		}
		let parentCloudPath = try itemMetadataManager.getCloudPath(for: parentID)
		return parentCloudPath.appendingPathComponent(name)
	}

	/**
	 Checks if there is a local item collision.

	 A local item collision occurs if there is already an item in the DB that has the passed `path` as path and there is no existing `DeleteItemTask` for this item.
	 Because in case of an existing `DeleteItemTask`, there is no conflict as the item can be considered as deleted.
	 */
	func checkLocalItemCollision(for path: CloudPath) throws {
		if let existingItemMetadata = try itemMetadataManager.getCachedMetadata(for: path) {
			do {
				_ = try deletionTaskManager.getTaskRecord(for: existingItemMetadata.id!)
			} catch DBManagerError.taskNotFound {
				throw NSError.fileProviderErrorForCollision(with: FileProviderItem(metadata: existingItemMetadata, domainIdentifier: domainIdentifier))
			}
		}
	}

	// MARK: Favorite Rank

	public nonisolated func setFavoriteRank(_ favoriteRank: NSNumber?, forItemIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: (NSFileProviderItem?, Error?) -> Void) {
		let fileProviderItem: NSFileProviderItem
		do {
			let id = try convertFileProviderItemIdentifierToInt64(itemIdentifier)
			try itemMetadataManager.setFavoriteRank(to: favoriteRank?.int64Value, forItemWithID: id)
			fileProviderItem = try item(for: itemIdentifier)
		} catch {
			completionHandler(nil, error)
			return
		}
		completionHandler(fileProviderItem, nil)
	}

	// MARK: Tag Data

	public nonisolated func setTagData(_ tagData: Data?, forItemIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: (NSFileProviderItem?, Error?) -> Void) {
		let fileProviderItem: NSFileProviderItem
		do {
			let id = try convertFileProviderItemIdentifierToInt64(itemIdentifier)

			try itemMetadataManager.setTagData(to: cleanTagData(tagData), forItemWithID: id)
			fileProviderItem = try item(for: itemIdentifier)
		} catch {
			completionHandler(nil, error)
			return
		}
		completionHandler(fileProviderItem, nil)
	}

	/// Isolated explicitly, because a witness of the nonisolated protocol is otherwise inferred nonisolated, as is `enumerateItems`.
	@MainActor public func getItemIdentifier(for cloudPath: CloudPath) async throws -> NSFileProviderItemIdentifier {
		if cloudPath == CloudPath("/") {
			return .rootContainer
		}
		let parentCloudPath = cloudPath.deletingLastPathComponent()
		let parentItemIdentifier: NSFileProviderItemIdentifier
		if let parentItemMetadata = try itemMetadataManager.getCachedMetadata(for: parentCloudPath) {
			parentItemIdentifier = NSFileProviderItemIdentifier(domainIdentifier: domainIdentifier, itemID: parentItemMetadata.id!)
		} else {
			parentItemIdentifier = try await getItemIdentifier(for: parentCloudPath)
		}
		_ = try await enumerateItemsExtensively(for: parentItemIdentifier)
		guard let metadata = try itemMetadataManager.getCachedMetadata(for: cloudPath) else {
			throw NSFileProviderError(.noSuchItem)
		}
		return NSFileProviderItemIdentifier(domainIdentifier: domainIdentifier, itemID: metadata.id!)
	}

	func enumerateItemsExtensively(for identifier: NSFileProviderItemIdentifier, withPageToken pageToken: String? = nil) async throws -> FileProviderItemList {
		let itemList = try await enumerateItems(for: identifier, withPageToken: pageToken)
		if let pageToken = pageToken {
			return try await enumerateItemsExtensively(for: identifier, withPageToken: pageToken)
		}
		return itemList
	}

	// MARK: Internal

	/**
	 Clean the tagData.

	 Helper function for `setTagData(_: forItemIdentifier:, completionHandler:)`.
	 Sets `tagData` to nil as according to the documentation the Files app should pass`nil` as tagData argument for `setTagData(_: forItemIdentifier:, completionHandler:)` if the tag gets removed, but actually passes empty data.
	 */
	nonisolated func cleanTagData(_ tagData: Data?) -> Data? {
		var maybeTagData = tagData
		if let tagData = tagData, tagData.isEmpty {
			maybeTagData = nil
		}
		return maybeTagData
	}

	nonisolated func getCachedMetadata(for identifier: NSFileProviderItemIdentifier) throws -> ItemMetadata {
		let id = try convertFileProviderItemIdentifierToInt64(identifier)
		guard let itemMetadata = try itemMetadataManager.getCachedMetadata(for: id) else {
			throw NSFileProviderError(.noSuchItem)
		}
		return itemMetadata
	}

	nonisolated func convertFileProviderItemIdentifierToInt64(_ identifier: NSFileProviderItemIdentifier) throws -> Int64 {
		guard let id = identifier.databaseValue else {
			throw FileProviderAdapterError.unsupportedItemIdentifier
		}
		return id
	}

	func convertIDToItemIdentifier(_ id: Int64) -> NSFileProviderItemIdentifier {
		if id == NSFileProviderItemIdentifier.rootContainerDatabaseValue {
			return .rootContainer
		}
		return NSFileProviderItemIdentifier(domainIdentifier: domainIdentifier, itemID: id)
	}

	private nonisolated func makeFileCoordinator() -> NSFileCoordinator {
		let fileCoordinator = NSFileCoordinator()
		fileCoordinator.purposeIdentifier = fileCoordinatorPurposeIdentifier
		return fileCoordinator
	}

	/// The provider awaits the returned hook before it resumes the task, which is what makes registration precede the transfer.
	private nonisolated func makeTaskRegistrationHook<T: URLSessionTask>(for identifier: NSFileProviderItemIdentifier, taskName: String) -> @concurrent @Sendable (T) async -> Void {
		let taskRegistrator = taskRegistrator
		return { urlSessionTask in
			do {
				try await taskRegistrator.register(urlSessionTask, forItemWithIdentifier: identifier)
				DDLogInfo("Successfully registered \(taskName) for identifier: \(identifier)")
			} catch {
				DDLogError("Register \(taskName) for identifier: \(identifier) failed with error: \(error)")
			}
		}
	}

	// MARK: Workflow Registry

	/// Runs `operation` on the main actor in submission order, which independent `Task`s would not guarantee.
	private nonisolated func submit(_ operation: @escaping @MainActor @Sendable () -> Void) {
		DispatchQueue.main.async {
			operation()
		}
	}

	/// Registers the task in the same synchronous stretch that creates it, so its cleanup cannot run before it is registered.
	private func start(for identifier: NSFileProviderItemIdentifier?, _ body: @escaping @MainActor () async -> Void) {
		let id = UUID()
		let task = Task { @MainActor in
			defer {
				workflows[id] = nil
			}
			await body()
		}
		workflows[id] = (identifier, task)
	}

	private func run<T: Sendable>(_ workflow: Workflow<T>, for identifier: NSFileProviderItemIdentifier?) async throws -> T {
		return try await withCheckedThrowingContinuation { continuation in
			start(for: identifier) {
				do {
					let value = try await self.scheduler.schedule(workflow)
					continuation.resume(returning: value)
				} catch {
					continuation.resume(throwing: error)
				}
			}
		}
	}

	private func startWorkflow(_ workflow: Workflow<FileProviderItem>, for identifier: NSFileProviderItemIdentifier) {
		start(for: identifier) {
			do {
				let item = try await self.scheduler.schedule(workflow)
				self.notificator?.signalUpdate(for: item)
			} catch {
				// Domain and code only, because a `FileManager` error names the path it failed on.
				let error = error as NSError
				DDLogError("Workflow for identifier: \(identifier) failed with \(error.domain) \(error.code)")
			}
		}
	}

	/// Lets pending submissions run first, then waits until no workflow is registered anymore.
	func awaitWorkflows() async {
		await withCheckedContinuation { continuation in
			DispatchQueue.main.async {
				continuation.resume()
			}
		}
		while let entry = workflows.first?.value {
			await entry.task.value
		}
	}

	struct LocalItemImportResult {
		let item: FileProviderItem
		let uploadTaskRecord: UploadTaskRecord
	}

	struct LocalPackageImportResult {
		let item: FileProviderItem
		let rootNode: ImportedPackageNode
	}

	/**
	 Keyed by parent rather than flattened, because each node's workflow is created only after its parent folder was created in the cloud.
	 Carries the `localURL` of a file, because `registerFileInUploadQueue` needs it later and nothing else recomputes it.
	 */
	struct ImportedPackageNode {
		let itemMetadata: ItemMetadata
		let localURL: URL?
		let children: [ImportedPackageNode]
	}

	struct MoveItemLocallyResult {
		let item: FileProviderItem
		let reparentTaskRecord: ReparentTaskRecord
	}
}
