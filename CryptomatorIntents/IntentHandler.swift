//
//  IntentHandler.swift
//  CryptomatorIntents
//
//  Created by Philipp Schmid on 13.05.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import Intents

class IntentHandler: INExtension {
	override func handler(for intent: INIntent) -> Any {
		if intent is SaveFileIntent {
			return SaveFileIntentHandler()
		}
		if intent is GetFolderIntent {
			return GetFolderIntentHandler()
		}
		if intent is LockVaultIntent {
			return LockVaultIntentHandler()
		}
		return self
	}
}
