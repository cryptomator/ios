//
//  DetectedVaultFailureView.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 28.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import UIKit

class DetectedVaultFailureView: UIView {
	private lazy var label: UILabel = {
		let label = UILabel()
		label.numberOfLines = 0
		label.lineBreakMode = .byWordWrapping
		label.textAlignment = .center
		label.adjustsFontForContentSizeCategory = true
		label.font = .preferredFont(forTextStyle: .body)
		return label
	}()

	init(text: String) {
		super.init(frame: .zero)
		let configuration = UIImage.SymbolConfiguration(pointSize: 120)
		let warningSymbol = UIImage(systemName: "exclamationmark.triangle.fill", withConfiguration: configuration)
		let imageView = UIImageView(image: warningSymbol)
		imageView.tintColor = .cryptomatorYellow

		label.text = text
		imageView.contentMode = .scaleAspectFit
		imageView.translatesAutoresizingMaskIntoConstraints = false
		label.translatesAutoresizingMaskIntoConstraints = false

		addSubview(imageView)
		addSubview(label)

		NSLayoutConstraint.activate([
			imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
			label.leadingAnchor.constraint(equalTo: readableContentGuide.leadingAnchor),
			label.trailingAnchor.constraint(equalTo: readableContentGuide.trailingAnchor),
			imageView.topAnchor.constraint(equalTo: topAnchor, constant: 20),
			label.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 20),
			label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20)
		])
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}
