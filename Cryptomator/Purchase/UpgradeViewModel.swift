//
//  UpgradeViewModel.swift
//  Cryptomator
//
//  Created by Tobias Hagemann on 08.09.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import Foundation
import UIKit

enum UpgradeButtonAction {
	case paidUpgrade
	case freeUpgrade
	case decideLater
}

private enum UpgradeSection {
	case paidUpgradeSection
	case freeUpgradeSection
	case decideLaterSection
}

struct UpgradeViewModel {
	private var sections: [UpgradeSection] = [.paidUpgradeSection, .freeUpgradeSection, .decideLaterSection]

	var numberOfSections: Int {
		return sections.count
	}

	func numberOfRows(in section: Int) -> Int {
		switch sections[section] {
		case .paidUpgradeSection:
			return 1
		case .freeUpgradeSection:
			return 1
		case .decideLaterSection:
			return 1
		}
	}

	func title(for indexPath: IndexPath) -> String {
		switch sections[indexPath.section] {
		case .paidUpgradeSection:
			return LocalizedString.getValue("upgrade.paidUpgrade.button")
		case .freeUpgradeSection:
			return LocalizedString.getValue("upgrade.freeUpgrade.button")
		case .decideLaterSection:
			return LocalizedString.getValue("upgrade.decideLater.button")
		}
	}

	func buttonAction(for indexPath: IndexPath) -> UpgradeButtonAction {
		switch sections[indexPath.section] {
		case .paidUpgradeSection:
			return .paidUpgrade
		case .freeUpgradeSection:
			return .freeUpgrade
		case .decideLaterSection:
			return .decideLater
		}
	}

	func footerTitle(for section: Int) -> String? {
		switch sections[section] {
		case .paidUpgradeSection:
			return LocalizedString.getValue("upgrade.paidUpgrade.footer")
		case .freeUpgradeSection:
			return LocalizedString.getValue("upgrade.freeUpgrade.footer")
		case .decideLaterSection:
			return LocalizedString.getValue("upgrade.decideLater.footer")
		}
	}
}
