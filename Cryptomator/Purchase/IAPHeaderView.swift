//
//  IAPHeaderView.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 07.03.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import UIKit

class IAPHeaderView: UITableViewHeaderFooterView {
	lazy var infoLabel: UILabel = {
		let label = AutoHidingLabel()
		label.numberOfLines = 0
		label.textAlignment = .center
		return label
	}()

	private lazy var imageView: UIImageView = {
		let image = UIImage(named: "bot")
		let imageView = UIImageView(image: image)
		imageView.contentMode = .scaleAspectFit
		return imageView
	}()

	private lazy var features = HeaderFeatures(features: [
		LocalizedString.getValue("purchase.header.feature.writeAccess"),
		LocalizedString.getValue("purchase.header.feature.openSource"),
		LocalizedString.getValue("purchase.header.feature.familySharing")
	])

	private lazy var separator: UIView = {
		let separator = UIView()
		separator.backgroundColor = .separator
		return separator
	}()

	private var separatorWeight: CGFloat {
		return 4.0 / UIScreen.main.scale
	}

	private lazy var bottomStack: UIStackView = {
		let stack = UIStackView(arrangedSubviews: [separator, infoLabel])
		stack.axis = .vertical
		stack.spacing = headerElementSpacing
		return stack
	}()

	override init(reuseIdentifier: String?) {
		super.init(reuseIdentifier: reuseIdentifier)
		setupViews()
	}

	let headerTopBottomPadding: CGFloat = 28
	let headerElementSpacing: CGFloat = 32

	func setupViews() {
		contentView.addSubview(imageView)
		contentView.addSubview(features)
		contentView.addSubview(bottomStack)

		imageView.translatesAutoresizingMaskIntoConstraints = false
		features.translatesAutoresizingMaskIntoConstraints = false
		separator.translatesAutoresizingMaskIntoConstraints = false
		bottomStack.translatesAutoresizingMaskIntoConstraints = false

		let featuresTopAnchor = features.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor, constant: headerTopBottomPadding)
		let bottomStackBottomAnchor = bottomStack.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor, constant: headerTopBottomPadding * -1)
		featuresTopAnchor.priority = .almostRequired
		bottomStackBottomAnchor.priority = .almostRequired

		NSLayoutConstraint.activate([
			imageView.centerYAnchor.constraint(equalTo: features.centerYAnchor),
			imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
			imageView.trailingAnchor.constraint(equalTo: features.leadingAnchor, constant: -16),
			imageView.widthAnchor.constraint(equalToConstant: 64),
			imageView.heightAnchor.constraint(equalToConstant: 64),

			featuresTopAnchor,
			features.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

			bottomStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
			bottomStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
			bottomStack.topAnchor.constraint(equalTo: features.bottomAnchor, constant: headerElementSpacing),
			separator.heightAnchor.constraint(equalToConstant: separatorWeight),
			bottomStackBottomAnchor
		])
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	class HeaderFeatures: UIView {
		private let textStyle: UIFont.TextStyle = .body
		private lazy var featureLabel: UILabel = {
			let label = UILabel()
			label.numberOfLines = 0
			label.font = .preferredFont(forTextStyle: textStyle)
			label.adjustsFontForContentSizeCategory = true
			return label
		}()

		override var intrinsicContentSize: CGSize {
			return featureLabel.intrinsicContentSize
		}

		init(features: [String]) {
			super.init(frame: .zero)
			featureLabel.attributedText = createAttributedString(from: features)
			setupViews()
		}

		@available(*, unavailable)
		required init?(coder: NSCoder) {
			fatalError("init(coder:) has not been implemented")
		}

		private func setupViews() {
			featureLabel.translatesAutoresizingMaskIntoConstraints = false
			addSubview(featureLabel)
			NSLayoutConstraint.activate([
				featureLabel.topAnchor.constraint(equalTo: topAnchor),
				featureLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
				featureLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
				featureLabel.trailingAnchor.constraint(equalTo: trailingAnchor)
			])
		}

		private func createAttributedString(from features: [String]) -> NSAttributedString {
			let configuration = UIImage.SymbolConfiguration(textStyle: textStyle)
			let imageAttachment = NSTextAttachment()
			imageAttachment.image = UIImage(systemName: "checkmark.circle.fill", withConfiguration: configuration)?.withTintColor(.cryptomatorPrimary)
			let attributedImageString = NSMutableAttributedString(attachment: imageAttachment)

			let attributedString = NSMutableAttributedString(string: "")

			features.enumerated().forEach {
				attributedString.append(attributedImageString)
				attributedString.append(NSAttributedString(string: "\t\($1)"))
				if $0 < features.count - 1 {
					attributedString.append(NSAttributedString(string: "\n"))
				}
			}

			attributedString.addAttribute(.foregroundColor,
			                              value: UIColor.label,
			                              range: NSRange(location: 0, length: attributedString.length))
			attributedString.addAttribute(.font,
			                              value: UIFont.preferredFont(forTextStyle: textStyle),
			                              range: NSRange(location: 0, length: attributedString.length))
			if let image = imageAttachment.image {
				let paragraphStyle = createParagraphStyle(from: image)
				attributedString.addAttributes(
					[.paragraphStyle: paragraphStyle],
					range: NSRange(location: 0, length: attributedString.length)
				)
			}
			return attributedString
		}

		private func createParagraphStyle(from image: UIImage) -> NSParagraphStyle {
			let indentation: CGFloat = image.size.width + 5
			let paragraphStyle = NSMutableParagraphStyle()
			paragraphStyle.tabStops = [NSTextTab(textAlignment: .left, location: indentation, options: [:])]
			paragraphStyle.headIndent = indentation
			paragraphStyle.lineHeightMultiple = 1.2

			return paragraphStyle
		}
	}
}
