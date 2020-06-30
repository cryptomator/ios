//
//  FileProviderExtension.swift
//  File Provider Extension
//
//  Created by Philipp Schmid on 17.06.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CloudAccessPrivate
import CryptomatorCloudAccess
import CryptomatorFileProvider
import FileProvider
class FileProviderExtension: NSFileProviderExtension {
	var fileManager = FileManager()
	private var decorator: FileProviderDecorator?
	override init() {
		super.init()
	}

	override func item(for identifier: NSFileProviderItemIdentifier) throws -> NSFileProviderItem {
		// resolve the given identifier to a record in the model
		// TODO: implement the actual lookup
		// TODO: Change domain stuff, decorator init, etc.
		guard let domain = self.domain else {
			let identifier = NSFileProviderDomainIdentifier("testDomain")
			let testDomain = NSFileProviderDomain(identifier: identifier, displayName: "Test", pathRelativeToDocumentStorage: "/Test/")
			NSFileProviderManager.add(testDomain) { error in
				if let error = error {
					print("Domain Registration Error: \(error)")
				}
			}
			throw NSError(domain: NSCocoaErrorDomain, code: NSFeatureUnsupportedError, userInfo: [:])
		}
		if decorator == nil {
			decorator = try FileProviderDecorator(for: domain.identifier)
		}
		return try decorator!.getFileProviderItem(for: identifier)
	}

	override func urlForItem(withPersistentIdentifier identifier: NSFileProviderItemIdentifier) -> URL? {
		// resolve the given identifier to a file on disk
		guard let item = try? item(for: identifier) else {
			return nil
		}

		// in this implementation, all paths are structured as <base storage directory>/<item identifier>/<item file name>
		let manager = NSFileProviderManager.default
		let perItemDirectory = manager.documentStorageURL.appendingPathComponent(identifier.rawValue, isDirectory: true)
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

		completionHandler(NSError(domain: NSCocoaErrorDomain, code: NSFeatureUnsupportedError, userInfo: [:]))
	}

	override func itemChanged(at _: URL) {
		// Called at some point after the file has changed; the provider may then trigger an upload

		/* TODO:
		 - mark file at <url> as needing an update in the model
		 - if there are existing NSURLSessionTasks uploading this file, cancel them
		 - create a fresh background NSURLSessionTask and schedule it to upload the current modifications
		 - register the NSURLSessionTask with NSFileProviderManager to provide progress updates
		 */
	}

	override func stopProvidingItem(at url: URL) {
		// Called after the last claim to the file has been released. At this point, it is safe for the file provider to remove the content file.
		// Care should be taken that the corresponding placeholder file stays behind after the content file has been deleted.

		// Called after the last claim to the file has been released. At this point, it is safe for the file provider to remove the content file.

		// TODO: look up whether the file has local changes
		let fileHasLocalChanges = false

		if !fileHasLocalChanges {
			// remove the existing file to free up space
			do {
				_ = try FileManager.default.removeItem(at: url)
			} catch {
				// Handle error
			}

			// write out a placeholder to facilitate future property lookups
			providePlaceholder(at: url, completionHandler: { _ in
				// TODO: handle any error, do any necessary cleanup
            })
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
		guard let domain = self.domain else {
			let identifier = NSFileProviderDomainIdentifier("testDomain")
			let testDomain = NSFileProviderDomain(identifier: identifier, displayName: "Test", pathRelativeToDocumentStorage: "/Test/")
			NSFileProviderManager.add(testDomain) { error in
				if let error = error {
					print("Domain Registration Error: \(error)")
				}
			}
			throw NSError(domain: NSCocoaErrorDomain, code: NSFeatureUnsupportedError, userInfo: [:])
		}
		if decorator == nil {
			decorator = try FileProviderDecorator(for: domain.identifier)
		}
		print("enumerator containerIdentifier: \(containerItemIdentifier)")
		return FileProviderEnumerator(enumeratedItemIdentifier: containerItemIdentifier, decorator: decorator!)
	}
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
