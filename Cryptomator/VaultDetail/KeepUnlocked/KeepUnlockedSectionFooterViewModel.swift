//
//  KeepUnlockedSectionFooterViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 14.01.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import Combine
import CryptomatorCommonCore
import Foundation

class KeepUnlockedSectionFooterViewModel: BindableAttributedTextHeaderFooterViewModel {
	private let keepUnlockedDuration: Bindable<KeepUnlockedDuration>
	private var subscriber: AnyCancellable?

	init(keepUnlockedDuration: Bindable<KeepUnlockedDuration>) {
		self.keepUnlockedDuration = keepUnlockedDuration
		let text = KeepUnlockedSectionFooterViewModel.getFooterText(for: keepUnlockedDuration.value)
		super.init(attributedText: text)
		setupBinding()
	}

	private func setupBinding() {
		subscriber = keepUnlockedDuration.$value.receive(on: DispatchQueue.main).sink { [weak self] keepUnlockedDuration in
			self?.attributedText.value = KeepUnlockedSectionFooterViewModel.getFooterText(for: keepUnlockedDuration)
		}
	}

	private static func getFooterText(for keepUnlockedDuration: KeepUnlockedDuration) -> NSAttributedString {
		let infoText: String
		switch keepUnlockedDuration {
		case .auto:
			infoText = LocalizedString.getValue("keepUnlocked.footer.auto")
		case .fiveMinutes, .tenMinutes, .thirtyMinutes, .oneHour, .indefinite:
			infoText = LocalizedString.getValue("keepUnlocked.footer.on")
		}
		let text = NSMutableAttributedString(string: infoText)
		text.append(NSAttributedString(string: " "))
		let learnMoreLink = NSAttributedString(string: LocalizedString.getValue("common.footer.learnMore"), attributes: [NSAttributedString.Key.link: URL(string: "https://docs.cryptomator.org/en/1.6/ios/vault-management/#unlock-duration")!])
		text.append(learnMoreLink)
		return text
	}
}
