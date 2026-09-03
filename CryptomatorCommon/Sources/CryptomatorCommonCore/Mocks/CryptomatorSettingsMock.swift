//
//  CryptomatorSettingsMock.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 23.11.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

#if DEBUG
import Foundation

class CryptomatorSettingsMock: CryptomatorSettings {
	var trialExpirationDate: Date?
	var debugModeEnabled: Bool = false
	var fullVersionUnlocked: Bool = false
	var hasRunningSubscription: Bool = false
	var trustedHubAuthorities: Set<String> = []
	#if !ALWAYS_PREMIUM
	var summer2026BannerDismissed: Bool = false
	var summer2026UnlockPromoShown: Bool = false
	#endif
}
#endif
