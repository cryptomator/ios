//
//  ChooseCloudViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 25.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
struct ChooseCloudViewModel: SingleSectionHeaderTableViewModelProtocol {
	let clouds: [CloudProviderType]
	let headerTitle: String
	let headerUppercased = false
}
