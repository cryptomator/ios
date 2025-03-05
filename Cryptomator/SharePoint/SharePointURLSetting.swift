//
//  SharePointURLSetting.swift
//  Cryptomator
//
//  Created by Majid Achhoud on 03.12.24.
//  Copyright © 2024 Skymatic GmbH. All rights reserved.
//

import Foundation

protocol SharePointURLSetting: AnyObject {
	func setSharePointURL(_ url: URL)
}
