//
//  OnboardingViewModel.swift
//  Cryptomator
//
//  Created by Tobias Hagemann on 08.09.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import Foundation
import UIKit

enum OnboardingButtonAction {
	case showIAP
	case unknown
}

private enum OnboardingSection: Int, CaseIterable {
	case mainSection = 0
}

struct OnboardingViewModel {
	var numberOfSections: Int {
		return OnboardingSection.allCases.count
	}

	func numberOfRows(in section: Int) -> Int {
		switch OnboardingSection(rawValue: section) {
		case .mainSection:
			return 1
		case nil:
			return 0
		}
	}

	func title(for indexPath: IndexPath) -> String {
		switch OnboardingSection(rawValue: indexPath.section) {
		case .mainSection:
			return LocalizedString.getValue("onboarding.button.continue")
		case nil:
			return ""
		}
	}

	func buttonAction(for indexPath: IndexPath) -> OnboardingButtonAction {
		switch OnboardingSection(rawValue: indexPath.section) {
		case .mainSection:
			return .showIAP
		case nil:
			return .unknown
		}
	}

	func accessoryType(for indexPath: IndexPath) -> UITableViewCell.AccessoryType {
		switch OnboardingSection(rawValue: indexPath.section) {
		case .mainSection:
			return .disclosureIndicator
		case nil:
			return .none
		}
	}
}
