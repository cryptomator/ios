//
//  AddVaultSuccessViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 30.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import UIKit

class AddVaultSuccessViewController: SingleSectionStaticUITableViewController {
	private let viewModel: AddVaultSuccessViewModel

	weak var coordinator: AddVaultSuccesing?

	init(viewModel: AddVaultSuccessViewModel) {
		self.viewModel = viewModel
		super.init(viewModel: viewModel)
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))
		navigationItem.rightBarButtonItem = doneButton
	}

	@objc func done() {
		coordinator?.done()
	}

	func openFilesApp() {
		coordinator?.showFilesApp(forVaultUID: viewModel.vaultUID)
	}

	// MARK: - UITableViewDelegate

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		tableView.deselectRow(at: indexPath, animated: true)
		openFilesApp()
	}

	override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		return VaultSuccessHeaderView(vaultName: viewModel.vaultName)
	}

	override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
		return VaultSuccessFooterView()
	}
}

private class VaultSuccessHeaderView: UIView {
	private lazy var successImage: UIImageView = {
		let image = UIImage(named: "bot")
		let imageView = UIImageView(image: image)
		imageView.contentMode = .scaleAspectFit
		return imageView
	}()

	private lazy var infoLabel: UILabel = {
		let label = UILabel()
		label.textAlignment = .center
		label.numberOfLines = 0
		return label
	}()

	convenience init(vaultName: String) {
		self.init(frame: .zero)
		infoLabel.text = String(format: LocalizedString.getValue("addVault.success.info"), vaultName)
		let stack = UIStackView(arrangedSubviews: [successImage, infoLabel])
		stack.translatesAutoresizingMaskIntoConstraints = false
		stack.axis = .vertical
		stack.spacing = 20
		addSubview(stack)

		NSLayoutConstraint.activate([
			stack.leadingAnchor.constraint(equalTo: readableContentGuide.leadingAnchor),
			stack.trailingAnchor.constraint(equalTo: readableContentGuide.trailingAnchor),
			stack.topAnchor.constraint(equalTo: topAnchor, constant: 20),
			stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20)
		])
	}
}

private class VaultSuccessFooterView: UITableViewHeaderFooterView {
	private lazy var textView: UITextView = {
		let textView = UITextView()
		textView.backgroundColor = .clear
		textView.isEditable = false
		textView.isScrollEnabled = false

		textView.textContainerInset = .zero
		textView.textContainer.lineFragmentPadding = 0

		let text = NSMutableAttributedString(string: LocalizedString.getValue("addVault.success.footer"), attributes: [NSAttributedString.Key.foregroundColor: UIColor.secondaryLabel])
		text.append(NSAttributedString(string: " "))
		let learnMoreLink = NSAttributedString(string: LocalizedString.getValue("common.footer.learnMore"), attributes: [NSAttributedString.Key.link: URL(string: "https://cryptomator.org")!]) // TODO: replace link
		text.append(learnMoreLink)
		textView.attributedText = text
		textView.isUserInteractionEnabled = true
		textView.font = .preferredFont(forTextStyle: .footnote)

		return textView
	}()

	override init(reuseIdentifier: String?) {
		super.init(reuseIdentifier: reuseIdentifier)
		configureContents()
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func configureContents() {
		textView.translatesAutoresizingMaskIntoConstraints = false
		contentView.addSubview(textView)

		NSLayoutConstraint.activate([
			textView.leadingAnchor.constraint(equalTo: contentView.readableContentGuide.leadingAnchor),
			textView.trailingAnchor.constraint(equalTo: contentView.readableContentGuide.trailingAnchor),
			textView.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
			textView.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor)
		])
	}
}

#if DEBUG
import SwiftUI

struct AddVaultSuccessVCPreview: PreviewProvider {
	static var previews: some View {
		AddVaultSuccessViewController(viewModel: AddVaultSuccessViewModel(vaultName: "Work", vaultUID: "")).toPreview()
	}
}
#endif
