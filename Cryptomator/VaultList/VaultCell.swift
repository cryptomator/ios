//
//  VaultCell.swift
//  Cryptomator
//
//  Created by Tobias Hagemann on 12.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Combine
import UIKit

class VaultCell: UITableViewCell, ConfigurableTableViewCell {
	private weak var viewModel: VaultCellViewModel?
	private var buttonSubscriber: AnyCancellable?

	private lazy var lockButton: ActionButton = {
		let button = ActionButton()
		let lockSymbol = UIImage(systemName: "lock.open.fill",
		                         withConfiguration: UIImage.SymbolConfiguration(pointSize: 26, weight: .regular, scale: .default))
		button.setImage(lockSymbol, for: .normal)
		button.sizeToFit()
		button.isHidden = true
		button.primaryAction = { [weak self] _ in
			self?.lockButtonAction()
		}
		return button
	}()

	override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
		super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
		setCustomAccessoryView()
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func configure(with viewModel: TableViewCellViewModel) {
		guard let viewModel = viewModel as? VaultCellViewModel else {
			return
		}
		configure(with: viewModel)
	}

	func configure(with viewModel: VaultCellViewModel) {
		buttonSubscriber = viewModel.lockButtonIsHidden.assign(to: \.isHidden, on: lockButton)
		self.viewModel = viewModel
		let vault = viewModel.vault
		imageView?.image = UIImage(vaultIconFor: vault.cloudProviderType, state: .normal)
		imageView?.highlightedImage = UIImage(vaultIconFor: vault.cloudProviderType, state: .highlighted)
		textLabel?.text = vault.vaultName
		detailTextLabel?.text = vault.vaultPath.path
		detailTextLabel?.textColor = .secondaryLabel
	}

	private func setCustomAccessoryView() {
		let detailDisclosureIndicator = UIImageView(image: UIImage(systemName: "chevron.forward",
		                                                           withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold, scale: .default)))
		detailDisclosureIndicator.tintColor = .tertiaryLabel
		detailDisclosureIndicator.contentMode = .right
		let containerView = UIStackView(arrangedSubviews: [lockButton, detailDisclosureIndicator])
		let spacing: CGFloat = 10
		containerView.spacing = spacing
		let width = lockButton.bounds.width + detailDisclosureIndicator.bounds.width + spacing
		containerView.frame = CGRect(x: 0, y: 0, width: width, height: frame.height)
		accessoryView = containerView
	}

	private func lockButtonAction() {
		viewModel?.lockVault().then {
			let feedbackGenerator = UINotificationFeedbackGenerator()
			feedbackGenerator.notificationOccurred(.success)
		}
	}
}
