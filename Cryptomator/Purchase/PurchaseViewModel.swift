//
//  PurchaseViewModel.swift
//  Cryptomator
//
//  Created by Tobias Hagemann on 08.09.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import Foundation
import UIKit

enum PurchaseButtonAction {
	case showUpgrade
	case beginFreeTrial
	case purchaseFullVersion
	case restorePurchase
	case decideLater
}

private enum PurchaseSection {
	case upgradeSection
	case trialSection
	case purchaseSection
	case restoreSection
	case decideLaterSection
}

struct PurchaseViewModel {
	private var sections: [PurchaseSection] = [.upgradeSection, .trialSection, .purchaseSection, .restoreSection, .decideLaterSection]

	var numberOfSections: Int {
		return sections.count
	}

	func numberOfRows(in section: Int) -> Int {
		switch sections[section] {
		case .upgradeSection:
			return 1
		case .trialSection:
			return 1
		case .purchaseSection:
			return 1
		case .restoreSection:
			return 1
		case .decideLaterSection:
			return 1
		}
	}

	func title(for indexPath: IndexPath) -> String {
		switch sections[indexPath.section] {
		case .upgradeSection:
			return LocalizedString.getValue("upgrade.title")
		case .trialSection:
			return LocalizedString.getValue("purchase.beginFreeTrial.button")
		case .purchaseSection:
			return LocalizedString.getValue("purchase.purchaseFullVersion.button")
		case .restoreSection:
			return LocalizedString.getValue("purchase.restorePurchase.button")
		case .decideLaterSection:
			return LocalizedString.getValue("purchase.decideLater.button")
		}
	}

	func textColor(for indexPath: IndexPath) -> UIColor! {
		switch sections[indexPath.section] {
		case .upgradeSection:
			return UIColor.label
		case .trialSection:
			return UIColor(named: "primary")
		case .purchaseSection:
			return UIColor(named: "primary")
		case .restoreSection:
			return UIColor(named: "primary")
		case .decideLaterSection:
			return UIColor(named: "primary")
		}
	}

	func buttonAction(for indexPath: IndexPath) -> PurchaseButtonAction {
		switch sections[indexPath.section] {
		case .upgradeSection:
			return .showUpgrade
		case .trialSection:
			return .beginFreeTrial
		case .purchaseSection:
			return .purchaseFullVersion
		case .restoreSection:
			return .restorePurchase
		case .decideLaterSection:
			return .decideLater
		}
	}

	func accessoryType(for indexPath: IndexPath) -> UITableViewCell.AccessoryType {
		switch sections[indexPath.section] {
		case .upgradeSection:
			return .disclosureIndicator
		case .trialSection:
			return .none
		case .purchaseSection:
			return .none
		case .restoreSection:
			return .none
		case .decideLaterSection:
			return .none
		}
	}

	func footerTitle(for section: Int) -> String? {
		switch sections[section] {
		case .upgradeSection:
			return LocalizedString.getValue("purchase.upgrade.footer")
		case .trialSection:
			return LocalizedString.getValue("purchase.beginFreeTrial.footer")
		case .purchaseSection:
			return LocalizedString.getValue("purchase.purchaseFullVersion.footer")
		case .restoreSection:
			return LocalizedString.getValue("purchase.restorePurchase.footer")
		case .decideLaterSection:
			return LocalizedString.getValue("purchase.decideLater.footer")
		}
	}
}
