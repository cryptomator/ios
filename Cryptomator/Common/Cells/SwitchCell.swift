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
		switchControl.onTintColor = .cryptomatorPrimary
		accessoryView = switchControl
	}

	override func configure(with viewModel: TableViewCellViewModel) {
		super.configure(with: viewModel)
		guard let switchCellViewModel = viewModel as? SwitchCellViewModel else {
			return
		}
		switchControl.setOn(switchCellViewModel.isOn.value, animated: false)
		twoWayBinding(viewModel: switchCellViewModel)
	}

	private func twoWayBinding(viewModel: SwitchCellViewModel) {
		viewModel.isOn.$value.receive(on: DispatchQueue.main).sink { [weak self] value in
			self?.switchControl.setOn(value, animated: true)
		}.store(in: &subscribers)
		switchControl.publisher(for: .valueChanged)
			.sink(receiveValue: {
				viewModel.isOnButtonPublisher.send($0)
				viewModel.isOn.value = $0
			}).store(in: &subscribers)
	}
}
