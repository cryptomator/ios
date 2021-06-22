//
//  SettingsViewModel.swift
//  Cryptomator
//
//  Created by Tobias Hagemann on 04.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation
import UIKit

enum SettingsButtonAction: String {
	case showAbout
	case sendLogFile
	case unknown
}

private enum SettingsSection: Int {
	case aboutSection = 0
	case debugSection
}

struct SettingsViewModel {
	var numberOfSections: Int {
		return 2
	}

	func numberOfRows(in section: Int) -> Int {
		switch SettingsSection(rawValue: section) {
		case .aboutSection:
			return 1
		case .debugSection:
			return 1
		case nil:
			return 0
		}
	}

	func title(for indexPath: IndexPath) -> String {
		switch SettingsSection(rawValue: indexPath.section) {
		case .aboutSection:
			return NSLocalizedString("settings.aboutCryptomator", comment: "")
		case .debugSection:
			return NSLocalizedString("settings.sendLogFile", comment: "")
		case nil:
			return ""
		}
	}

	func buttonAction(for indexPath: IndexPath) -> SettingsButtonAction {
		switch SettingsSection(rawValue: indexPath.section) {
		case .aboutSection:
			return .showAbout
		case .debugSection:
			return .sendLogFile
		case nil:
			return .unknown
		}
	}

	func accessoryType(for indexPath: IndexPath) -> UITableViewCell.AccessoryType {
		switch SettingsSection(rawValue: indexPath.section) {
		case .aboutSection:
			return .disclosureIndicator
		case .debugSection:
			return .none
		case nil:
			return .none
		}
	}
}
