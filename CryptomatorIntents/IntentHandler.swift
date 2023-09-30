//
//  IntentHandler.swift
//  CryptomatorIntents
//
//  Created by Philipp Schmid on 13.05.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import CryptomatorCommonCore
import Intents

class IntentHandler: INExtension {
	override func handler(for intent: INIntent) -> Any {
		IntentHandler.oneTimeSetup()
		if intent is SaveFileIntent {
			return SaveFileIntentHandler()
		}
		if intent is GetFolderIntent {
			return GetFolderIntentHandler(vaultOptionsProvider: .shared)
		}
		if intent is LockVaultIntent {
			return LockVaultIntentHandler(vaultOptionsProvider: .shared)
		}
		if intent is OpenVaultIntent {
			return OpenVaultIntentHandler(vaultOptionsProvider: .shared)
		}
		if intent is IsVaultUnlockedIntent {
			return IsVaultUnlockedIntentHandler(vaultOptionsProvider: .shared)
		}
		return self
	}

	private static var oneTimeSetup: () -> Void = {
		// Set up logger
		LoggerSetup.oneTimeSetup()
	}
}
