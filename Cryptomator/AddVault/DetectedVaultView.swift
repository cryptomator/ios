//
//  DetectedVaultView.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 18.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import UIKit
class DetectedVaultView: UIView {
	private lazy var label: UILabel = {
		let label = UILabel()
		label.numberOfLines = 0
		label.lineBreakMode = .byWordWrapping
		label.textAlignment = .center
		return label
	}()

	init(imageView: UIImageView, text: String) {
		super.init(frame: .zero)
		label.text = text
		imageView.contentMode = .scaleAspectFit
		imageView.translatesAutoresizingMaskIntoConstraints = false
		label.translatesAutoresizingMaskIntoConstraints = false

		addSubview(imageView)
		addSubview(label)

		NSLayoutConstraint.activate([
			imageView.topAnchor.constraint(equalTo: topAnchor),
			imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
			label.leadingAnchor.constraint(equalTo: readableContentGuide.leadingAnchor),
			label.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 20),
			label.bottomAnchor.constraint(equalTo: bottomAnchor),
			label.trailingAnchor.constraint(equalTo: readableContentGuide.trailingAnchor)
		])
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}
