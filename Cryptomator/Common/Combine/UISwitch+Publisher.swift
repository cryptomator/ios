//
//  UISwitch+Publisher.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 06.08.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Combine
import UIKit

extension UISwitch {
	func publisher(for events: UIControl.Event) -> AnyPublisher<Bool, UIControlPublisher<UISwitch>.Failure> {
		return publisher(for: events).map { $0.isOn }.eraseToAnyPublisher()
	}
}
