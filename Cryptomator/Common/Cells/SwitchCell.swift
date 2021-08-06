//
//  SwitchCell.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 29.07.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Combine
import UIKit
class SwitchCell: TableViewCell {
	var switchControl = UISwitch(frame: .zero)

	override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
		super.init(style: style, reuseIdentifier: reuseIdentifier)
		accessoryView = switchControl
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func configure(with viewModel: TableViewCellViewModel) {
		super.configure(with: viewModel)
		guard let switchCellViewModel = viewModel as? SwitchCellViewModel else {
			return
		}
		twoWayBinding(viewModel: switchCellViewModel)
	}

	private func twoWayBinding(viewModel: SwitchCellViewModel) {
		viewModel.$isOn.receive(on: DispatchQueue.main).assign(to: \.isOn, on: switchControl).store(in: &subscribers)
		switchControl.publisher(for: .valueChanged)
			.sink(receiveValue: {
				viewModel.isOnButtonPublisher.send($0)
			}).store(in: &subscribers)
	}
}
