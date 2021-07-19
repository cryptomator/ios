//
//  OnboardingView.swift
//  FileProviderExtensionUI
//
//  Created by Philipp Schmid on 29.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import UIKit

class OnboardingView: UIView {
	private lazy var label: UILabel = {
		let label = UILabel()
		label.numberOfLines = 0
		label.lineBreakMode = .byWordWrapping
		label.textAlignment = .center
		return label
	}()

	lazy var cancelButton: UIButton = {
		let button = UIButton()
		button.setTitle(NSLocalizedString("common.button.ok", comment: ""), for: .normal)
		button.setTitleColor(UIColor(named: "primary"), for: .normal)
		return button
	}()

	init() {
		super.init(frame: .zero)

		let botVaultImage = UIImage(named: "bot-vault")
		let imageView = UIImageView(image: botVaultImage)

		label.text = NSLocalizedString("onboarding.info", comment: "")
		imageView.contentMode = .scaleAspectFit
		imageView.translatesAutoresizingMaskIntoConstraints = false
		label.translatesAutoresizingMaskIntoConstraints = false
		cancelButton.translatesAutoresizingMaskIntoConstraints = false

		addSubview(imageView)
		addSubview(label)
		addSubview(cancelButton)

		NSLayoutConstraint.activate([
			imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
			label.leadingAnchor.constraint(equalTo: readableContentGuide.leadingAnchor),
			label.trailingAnchor.constraint(equalTo: readableContentGuide.trailingAnchor),
			imageView.topAnchor.constraint(equalTo: topAnchor, constant: 20),

			label.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 20),
			label.bottomAnchor.constraint(equalTo: cancelButton.topAnchor, constant: -20),

			cancelButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
			cancelButton.centerXAnchor.constraint(equalTo: centerXAnchor)
		])
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}
