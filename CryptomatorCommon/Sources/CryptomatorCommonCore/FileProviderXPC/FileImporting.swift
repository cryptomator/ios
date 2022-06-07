//
//  FileImporting.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 13.05.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import FileProvider
import Foundation
import Promises

@objc public protocol FileImporting: NSFileProviderServiceSource {
	/**
	 Imports the file at the given `localURL` to the given `parentItemIdentifier`.

	 - Parameter localURL: The URL of the file to be imported
	 - Parameter parentItemIdentifier: The item identifier of the folder into which the file will be imported.
	 - Parameter reply: Reply block which gets called with `nil` once the file has been imported locally. If an error occurs when importing the file locally, the reply block gets called with this error.
	 */
	func importFile(at localURL: URL, toParentItemIdentifier parentItemIdentifier: String, reply: @escaping (NSError?) -> Void)

	/**
	 Returns the identifier for an item at the given path.

	 - Parameter path: The path of the item in the cloud
	 - Parameter reply: Reply block which is called with the `rawValue` of the `NSFileProviderItemIdentifier` if there is an item for the passed path in the cloud. If an error occurs while checking the path in the cloud, the reply block is called with it. Furthermore, the reply block is called with an error if the item does not exist in the cloud.
	 */
	func getIdentifierForItem(at path: String, reply: @escaping (NSString?, NSError?) -> Void)
}

public extension FileImporting {
	/**
	 Imports the file at the given `localURL` to the given `parentItemIdentifier`.

	 - Parameter localURL: The URL of the file to be imported
	 - Parameter parentItemIdentifier: The item identifier of the folder into which the file will be imported.
	 */
	func importFile(at localURL: URL, toParentItemIdentifier parentItemIdentifier: String) -> Promise<Void> {
		return wrap {
			self.importFile(at: localURL, toParentItemIdentifier: parentItemIdentifier, reply: $0)
		}.then { error -> Void in
			if let error = error {
				throw error
			}
		}
	}

	/**
	 Returns the identifier for an item at the given path.

	 - Parameter path: The path of the item in the cloud
	 */
	func getIdentifierForItem(at path: String) -> Promise<NSString> {
		return wrap {
			self.getIdentifierForItem(at: path, reply: $0)
		}.then {
			return $0!
		}
	}
}

public extension NSFileProviderServiceName {
	static let fileImporting = NSFileProviderServiceName("org.cryptomator.ios.file-importing")
}
