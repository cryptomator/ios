//
//  CloudItemCell.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 25.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import UIKit

protocol CloudItemCell: UITableViewCell {
	var item: CloudItemMetadata? { get set }
	func configure(with item: CloudItemMetadata)
}
