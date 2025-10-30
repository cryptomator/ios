//
//  ShareVaultViewController.swift
//  Cryptomator
//
//  Created by Majid Achhoud on 24.10.25.
//  Copyright © 2025 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import UIKit

class ShareVaultViewController: UIViewController {
	weak var coordinator: ShareVaultCoordinator?
	private let viewModel: ShareVaultViewModelProtocol

	// MARK: - Layout Constants

	private enum LayoutConstants {
		static let horizontalPadding: CGFloat = 32
		static let standardSpacing: CGFloat = 16
		static let largeSpacing: CGFloat = 32
		static let titleToSubtitleSpacing: CGFloat = 16
		static let subtitleToStepsSpacing: CGFloat = 20
		static let titleToFeaturesSpacing: CGFloat = 8
		static let titleSpacing: CGFloat = 24
		static let logoHeight: CGFloat = 44
		static let hubImageMultiplier: CGFloat = 0.7
		static let buttonHeight: CGFloat = 50
		static let iconSize: CGFloat = 24
		static let iconTextSpacing: CGFloat = 12
		static let stepsSpacing: CGFloat = 16
		static let cornerRadius: CGFloat = 12
	}

	// MARK: - UI Components

	private lazy var scrollView: UIScrollView = {
		let scrollView = UIScrollView()
		scrollView.translatesAutoresizingMaskIntoConstraints = false
		scrollView.alwaysBounceVertical = true
		return scrollView
	}()

	private lazy var contentView: UIView = {
		let view = UIView()
		view.translatesAutoresizingMaskIntoConstraints = false
		return view
	}()

	private lazy var logoImageView: UIImageView = {
		let imageView = UIImageView(image: UIImage(named: viewModel.logoImageName))
		imageView.contentMode = .scaleAspectFit
		imageView.translatesAutoresizingMaskIntoConstraints = false
		return imageView
	}()

	private lazy var hubImageView: UIImageView = {
		let imageView = UIImageView(image: UIImage(named: "cryptomator-hub"))
		imageView.contentMode = .scaleAspectFit
		imageView.layer.cornerRadius = LayoutConstants.cornerRadius
		imageView.clipsToBounds = true
		imageView.translatesAutoresizingMaskIntoConstraints = false
		return imageView
	}()

	private lazy var titleLabel: UILabel = {
		let label = UILabel()
		label.text = viewModel.headerTitle
		label.font = .preferredFont(forTextStyle: .title3)
		label.numberOfLines = 0
		label.textAlignment = .center
		label.adjustsFontForContentSizeCategory = true
		label.translatesAutoresizingMaskIntoConstraints = false
		return label
	}()

	private lazy var subtitleLabel: UILabel = {
		let label = UILabel()
		label.text = viewModel.headerSubtitle
		label.font = .preferredFont(forTextStyle: .subheadline)
		label.numberOfLines = 0
		label.textAlignment = .left
		label.textColor = .secondaryLabel
		label.adjustsFontForContentSizeCategory = true
		label.translatesAutoresizingMaskIntoConstraints = false
		return label
	}()

	private lazy var featuresLabel: UILabel = {
		let label = UILabel()
		label.text = viewModel.featuresText
		label.font = .preferredFont(forTextStyle: .subheadline)
		label.numberOfLines = 0
		label.textAlignment = .center
		label.textColor = .secondaryLabel
		label.adjustsFontForContentSizeCategory = true
		label.translatesAutoresizingMaskIntoConstraints = false
		return label
	}()

	private lazy var hubStepsStackView: UIStackView = {
		let stackView = UIStackView()
		stackView.axis = .vertical
		stackView.spacing = LayoutConstants.stepsSpacing
		stackView.alignment = .leading
		stackView.translatesAutoresizingMaskIntoConstraints = false
		return stackView
	}()

	private lazy var footerTextView: UITextView = {
		let textView = UITextView()
		textView.backgroundColor = .clear
		textView.isEditable = false
		textView.isScrollEnabled = false
		textView.isUserInteractionEnabled = true
		textView.textContainerInset = .zero
		textView.textContainer.lineFragmentPadding = 0
		textView.translatesAutoresizingMaskIntoConstraints = false
		textView.attributedText = createFooterAttributedText()
		return textView
	}()

	private lazy var visitHubButton: UIButton = {
		let button = UIButton(type: .system)
		button.setTitle(viewModel.forTeamsButtonTitle, for: .normal)
		button.backgroundColor = .cryptomatorPrimary
		button.setTitleColor(.white, for: .normal)
		button.titleLabel?.font = .preferredFont(forTextStyle: .headline)
		button.titleLabel?.adjustsFontForContentSizeCategory = true
		button.layer.cornerRadius = LayoutConstants.cornerRadius
		button.translatesAutoresizingMaskIntoConstraints = false
		button.addTarget(self, action: #selector(visitHubButtonTapped), for: .touchUpInside)
		return button
	}()

	init(viewModel: ShareVaultViewModelProtocol) {
		self.viewModel = viewModel
		super.init(nibName: nil, bundle: nil)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		title = viewModel.title
		view.backgroundColor = .cryptomatorBackground
		setupViews()
	}

	private func setupViews() {
		view.addSubview(scrollView)
		view.addSubview(visitHubButton)
		scrollView.addSubview(contentView)
		contentView.addSubview(logoImageView)
		contentView.addSubview(hubImageView)
		contentView.addSubview(titleLabel)

		if viewModel.headerSubtitle != nil {
			contentView.addSubview(subtitleLabel)
		}

		if let hubSteps = viewModel.hubSteps {
			setupHubStepsView(with: hubSteps)
			contentView.addSubview(hubStepsStackView)
		} else if viewModel.featuresText != nil {
			contentView.addSubview(featuresLabel)
		}

		if viewModel.footerText != nil {
			contentView.addSubview(footerTextView)
		}

		setupConstraints()
	}

	private func setupHubStepsView(with steps: [(String, String)]) {
		for (symbolName, text) in steps {
			let stepView = createStepView(symbolName: symbolName, text: text)
			hubStepsStackView.addArrangedSubview(stepView)
		}
	}

	private func createStepView(symbolName: String, text: String) -> UIView {
		let containerView = UIView()
		containerView.translatesAutoresizingMaskIntoConstraints = false

		let symbolImageView = UIImageView()
		symbolImageView.image = UIImage(systemName: symbolName)
		symbolImageView.tintColor = .cryptomatorPrimary
		symbolImageView.contentMode = .scaleAspectFit
		symbolImageView.translatesAutoresizingMaskIntoConstraints = false

		let textLabel = UILabel()
		textLabel.text = text
		textLabel.font = .preferredFont(forTextStyle: .subheadline)
		textLabel.numberOfLines = 0
		textLabel.textColor = .secondaryLabel
		textLabel.adjustsFontForContentSizeCategory = true
		textLabel.translatesAutoresizingMaskIntoConstraints = false

		containerView.addSubview(symbolImageView)
		containerView.addSubview(textLabel)

		NSLayoutConstraint.activate([
			symbolImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
			symbolImageView.topAnchor.constraint(equalTo: textLabel.topAnchor),
			symbolImageView.widthAnchor.constraint(equalToConstant: LayoutConstants.iconSize),
			symbolImageView.heightAnchor.constraint(equalToConstant: LayoutConstants.iconSize),

			textLabel.leadingAnchor.constraint(equalTo: symbolImageView.trailingAnchor, constant: LayoutConstants.iconTextSpacing),
			textLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
			textLabel.topAnchor.constraint(equalTo: containerView.topAnchor),
			textLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
		])

		return containerView
	}

	private func setupConstraints() {
		let contentLayoutGuide = scrollView.contentLayoutGuide
		let frameLayoutGuide = scrollView.frameLayoutGuide

		var constraints = createBaseConstraints(contentLayoutGuide: contentLayoutGuide, frameLayoutGuide: frameLayoutGuide)
		let topAnchor = addOptionalSubtitleConstraints(to: &constraints)
		let lastContentView = addContentConstraints(to: &constraints, topAnchor: topAnchor)
		addFooterConstraints(to: &constraints, lastContentView: lastContentView)

		NSLayoutConstraint.activate(constraints)
	}

	private func createBaseConstraints(contentLayoutGuide: UILayoutGuide, frameLayoutGuide: UILayoutGuide) -> [NSLayoutConstraint] {
		return [
			scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
			scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			scrollView.bottomAnchor.constraint(equalTo: visitHubButton.topAnchor, constant: -LayoutConstants.standardSpacing),

			contentView.topAnchor.constraint(equalTo: contentLayoutGuide.topAnchor),
			contentView.leadingAnchor.constraint(equalTo: contentLayoutGuide.leadingAnchor),
			contentView.trailingAnchor.constraint(equalTo: contentLayoutGuide.trailingAnchor),
			contentView.bottomAnchor.constraint(equalTo: contentLayoutGuide.bottomAnchor),
			contentView.widthAnchor.constraint(equalTo: frameLayoutGuide.widthAnchor),

			logoImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: LayoutConstants.largeSpacing),
			logoImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
			logoImageView.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.readableContentGuide.leadingAnchor),
			logoImageView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.readableContentGuide.trailingAnchor),
			logoImageView.heightAnchor.constraint(equalToConstant: LayoutConstants.logoHeight),

			hubImageView.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: LayoutConstants.largeSpacing),
			hubImageView.leadingAnchor.constraint(equalTo: contentView.readableContentGuide.leadingAnchor),
			hubImageView.trailingAnchor.constraint(equalTo: contentView.readableContentGuide.trailingAnchor),
			hubImageView.heightAnchor.constraint(equalTo: hubImageView.widthAnchor, multiplier: LayoutConstants.hubImageMultiplier),

			titleLabel.topAnchor.constraint(equalTo: hubImageView.bottomAnchor, constant: LayoutConstants.titleSpacing),
			titleLabel.leadingAnchor.constraint(equalTo: contentView.readableContentGuide.leadingAnchor),
			titleLabel.trailingAnchor.constraint(equalTo: contentView.readableContentGuide.trailingAnchor),

			visitHubButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: LayoutConstants.standardSpacing),
			visitHubButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -LayoutConstants.standardSpacing),
			visitHubButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -LayoutConstants.standardSpacing),
			visitHubButton.heightAnchor.constraint(equalToConstant: LayoutConstants.buttonHeight)
		]
	}

	private func addOptionalSubtitleConstraints(to constraints: inout [NSLayoutConstraint]) -> NSLayoutYAxisAnchor {
		guard viewModel.headerSubtitle != nil else {
			return titleLabel.bottomAnchor
		}

		constraints.append(contentsOf: [
			subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: LayoutConstants.titleToSubtitleSpacing),
			subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: LayoutConstants.horizontalPadding),
			subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -LayoutConstants.horizontalPadding)
		])
		return subtitleLabel.bottomAnchor
	}

	private func addContentConstraints(to constraints: inout [NSLayoutConstraint], topAnchor: NSLayoutYAxisAnchor) -> UIView {
		if viewModel.hubSteps != nil {
			constraints.append(contentsOf: [
				hubStepsStackView.topAnchor.constraint(equalTo: topAnchor, constant: LayoutConstants.subtitleToStepsSpacing),
				hubStepsStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: LayoutConstants.horizontalPadding),
				hubStepsStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -LayoutConstants.horizontalPadding)
			])
			return hubStepsStackView
		} else {
			constraints.append(contentsOf: [
				featuresLabel.topAnchor.constraint(equalTo: topAnchor, constant: LayoutConstants.titleToFeaturesSpacing),
				featuresLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: LayoutConstants.horizontalPadding),
				featuresLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -LayoutConstants.horizontalPadding)
			])
			return featuresLabel
		}
	}

	private func addFooterConstraints(to constraints: inout [NSLayoutConstraint], lastContentView: UIView) {
		if viewModel.footerText != nil {
			constraints.append(contentsOf: [
				footerTextView.topAnchor.constraint(equalTo: lastContentView.bottomAnchor, constant: LayoutConstants.largeSpacing),
				footerTextView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: LayoutConstants.horizontalPadding),
				footerTextView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -LayoutConstants.horizontalPadding),
				footerTextView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -LayoutConstants.titleSpacing)
			])
		} else {
			constraints.append(
				lastContentView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -LayoutConstants.titleSpacing)
			)
		}
	}

	private func createFooterAttributedText() -> NSAttributedString {
		guard let footerText = viewModel.footerText,
		      let docsButtonTitle = viewModel.docsButtonTitle,
		      let docsURL = viewModel.docsURL else {
			return NSAttributedString()
		}

		let paragraphStyle = NSMutableParagraphStyle()
		paragraphStyle.alignment = .center
		paragraphStyle.lineBreakMode = .byWordWrapping

		let font = UIFont.preferredFont(forTextStyle: .footnote)
		let textAttributes: [NSAttributedString.Key: Any] = [
			.foregroundColor: UIColor.secondaryLabel,
			.paragraphStyle: paragraphStyle,
			.font: font
		]
		let linkAttributes: [NSAttributedString.Key: Any] = [
			.link: docsURL,
			.paragraphStyle: paragraphStyle,
			.font: font
		]

		let text = NSMutableAttributedString(string: footerText, attributes: textAttributes)
		text.append(NSAttributedString(string: "\u{00A0}", attributes: textAttributes))
		text.append(NSAttributedString(string: docsButtonTitle, attributes: linkAttributes))
		text.append(NSAttributedString(string: ".", attributes: textAttributes))

		return text
	}

	@objc private func visitHubButtonTapped() {
		guard let url = viewModel.forTeamsURL else {
			return
		}
		UIApplication.shared.open(url)
	}
}
