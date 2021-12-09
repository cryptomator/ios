//
//  LargeHeaderFooterView.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 08.12.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import UIKit

open class LargeHeaderFooterView: UITableViewHeaderFooterView {
	public var infoText: String? {
		get {
			return infoLabel.text
		}
		set {
			infoLabel.isHidden = newValue == nil
			infoLabel.text = newValue
		}
	}

	public var image: UIImage? {
		get {
			return imageView.image
		}
		set {
			imageView.image = newValue
		}
	}

	private lazy var infoLabel: UILabel = {
		let label = UILabel()
		label.numberOfLines = 0
		label.lineBreakMode = .byWordWrapping
		label.textAlignment = .center
		label.adjustsFontForContentSizeCategory = true
		label.font = .preferredFont(forTextStyle: .body)
		return label
	}()

	private lazy var imageView: UIImageView = {
		let imageView = UIImageView()
		imageView.contentMode = .scaleAspectFit
		return imageView
	}()

	public init(image: UIImage?, infoText: String?) {
		super.init(reuseIdentifier: nil)
		configureContents()
		self.image = image
		self.infoText = infoText
	}

	override init(reuseIdentifier: String?) {
		super.init(reuseIdentifier: reuseIdentifier)
		configureContents()
	}

	@available(*, unavailable)
	public required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func configureContents() {
		let stack = UIStackView(arrangedSubviews: [imageView, infoLabel])
		stack.spacing = 20
		stack.distribution = .fillProportionally
		stack.axis = .vertical
		stack.translatesAutoresizingMaskIntoConstraints = false
		contentView.addSubview(stack)
		NSLayoutConstraint.activate([
			stack.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor, constant: 12),
			stack.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor, constant: -12),
			stack.leadingAnchor.constraint(equalTo: contentView.readableContentGuide.leadingAnchor),
			stack.trailingAnchor.constraint(equalTo: contentView.readableContentGuide.trailingAnchor)
		])
	}
}
