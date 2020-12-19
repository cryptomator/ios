//
//  CloudProvider+CreateIntermediateFolders.swift
//  CryptomatorIntegrationTests
//
//  Created by Philipp Schmid on 12.10.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess
import Foundation
import Promises
extension CloudProvider {
	func createFolderWithIntermediates(for cloudPath: CloudPath) -> Promise<Void> {
		guard cloudPath != CloudPath("/") else {
			return Promise(())
		}
		var path = CloudPath("/")
		let pathComponents = cloudPath.pathComponents.dropFirst()
		return Promise(on: .global()) { fulfill, reject in
			for component in pathComponents {
				path = path.appendingPathComponent(component)
				do {
					try (await (self.createFolder(at: path)))
				} catch {
					guard case CloudProviderError.itemAlreadyExists = error else {
						reject(error)
						return
					}
				}
			}
			fulfill(())
		}
	}
}
