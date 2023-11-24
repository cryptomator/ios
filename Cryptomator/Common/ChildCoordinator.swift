//
//  ChildCoordinator.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 18.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import Foundation

protocol ChildCoordinator: Coordinator {
	func stop()
	var parentCoordinator: Coordinator? { get set }
}
