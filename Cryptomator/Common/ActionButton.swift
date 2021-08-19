//
//  ActionButton.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 28.07.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import UIKit

class ActionButton: UIButton {
	var primaryAction: ((UIButton) -> Void)?

	init() {
		super.init(frame: .zero)
		addTarget(self, action: #selector(primaryActionTriggered(sender:)), for: .primaryActionTriggered)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	@objc private func primaryActionTriggered(sender: UIButton) {
		primaryAction?(sender)
	}
}
