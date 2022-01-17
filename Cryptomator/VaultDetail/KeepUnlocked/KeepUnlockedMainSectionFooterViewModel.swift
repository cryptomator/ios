//
//  KeepUnlockedMainSectionFooterViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 14.01.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import Combine
import CryptomatorCommonCore
import Foundation

class KeepUnlockedMainSectionFooterViewModel: AttributedTextHeaderFooterViewModel {
	init(keepUnlockedIsEnabled: Bool) {
		let infoText: String
		if keepUnlockedIsEnabled {
			infoText = LocalizedString.getValue("keepUnlocked.main.footer.on")
		} else {
			infoText = LocalizedString.getValue("keepUnlocked.main.footer.off")
		}
		let text = NSMutableAttributedString(string: infoText)
		text.append(NSAttributedString(string: " "))
		let learnMoreLink = NSAttributedString(string: LocalizedString.getValue("common.footer.learnMore"), attributes: [NSAttributedString.Key.link: URL(string: "https://docs.cryptomator.org/en/1.6/ios/vault-management/")!])
		text.append(learnMoreLink)
		super.init(attributedText: text)
	}
}
