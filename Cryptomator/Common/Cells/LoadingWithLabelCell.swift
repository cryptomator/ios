//
//  LoadingWithLabelCell.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 05.10.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import UIKit

class LoadingWithLabelCell: TableViewCell {
	private lazy var loadingIndicator: UIActivityIndicatorView = {
		let loadingIndicator = UIActivityIndicatorView(style: .medium)
		loadingIndicator.hidesWhenStopped = true
		return loadingIndicator
	}()

	private var isLoading: Bool {
		get {
			loadingIndicator.isAnimating
		}
		set {
			if newValue {
				detailTextLabel?.text = nil
				accessoryView = loadingIndicator
				loadingIndicator.startAnimating()
			} else {
				accessoryView = nil
				loadingIndicator.stopAnimating()
			}
		}
	}

	override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
		super.init(style: .value1, reuseIdentifier: reuseIdentifier)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func configure(with viewModel: TableViewCellViewModel) {
		super.configure(with: viewModel)
		guard let loadingWithLabelCellViewModel = viewModel as? LoadingWithLabelCellViewModel else {
			return
		}
		loadingWithLabelCellViewModel.isLoading.$value.receive(on: DispatchQueue.main).assign(to: \.isLoading, on: self).store(in: &subscribers)
	}
}
