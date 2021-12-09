//
//  LoadingButtonCell.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 07.12.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import UIKit

class LoadingButtonCell: ButtonTableViewCell {
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

	override func configure(with viewModel: TableViewCellViewModel) {
		super.configure(with: viewModel)
		guard let loadingIndicatorViewModel = viewModel as? LoadingIndicatorSupport else {
			return
		}
		loadingIndicatorViewModel.isLoading.$value.receive(on: DispatchQueue.main).assign(to: \.isLoading, on: self).store(in: &subscribers)
	}
}
