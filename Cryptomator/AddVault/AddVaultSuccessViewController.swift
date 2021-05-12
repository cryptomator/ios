//
//  AddVaultSuccessViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 30.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import UIKit

class AddVaultSuccessViewController: SingleSectionTableViewController {
	let vaultName: String
	weak var coordinator: AddVaultSuccesing?

	init(vaultName: String) {
		self.vaultName = vaultName
		super.init()
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))
		navigationItem.rightBarButtonItem = doneButton
		tableView.register(ButtonCell.self, forCellReuseIdentifier: "ButtonCell")
		tableView.rowHeight = 44
	}

	@objc func done() {
		coordinator?.done()
	}

	@objc func openFilesApp() {
		coordinator?.showFilesApp()
	}

	// MARK: - UITableViewDataSource

	override func numberOfSections(in tableView: UITableView) -> Int {
		return 1
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return 1
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		// swiftlint:disable:next force_cast
		let cell = tableView.dequeueReusableCell(withIdentifier: "ButtonCell", for: indexPath) as! ButtonCell
		cell.button.setTitle(NSLocalizedString("addVault.success.openFilesApp", comment: ""), for: .normal)
		cell.button.addTarget(self, action: #selector(openFilesApp), for: .touchUpInside)
		return cell
	}

	// MARK: - UITableViewDelegate

	override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		return VaultSuccessHeaderView(vaultName: vaultName)
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

	private lazy var infoText: UILabel = {
		let label = UILabel()
		label.textAlignment = .center
		label.numberOfLines = 0
		return label
	}()

	convenience init(vaultName: String) {
		self.init(frame: .zero)
		infoText.text = String(format: NSLocalizedString("addVault.success.info", comment: ""), vaultName)
		let stack = UIStackView(arrangedSubviews: [successImage, infoText])
		stack.translatesAutoresizingMaskIntoConstraints = false
		stack.axis = .vertical
		stack.spacing = 10
		addSubview(stack)

		NSLayoutConstraint.activate([
			stack.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
			stack.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
			stack.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
			stack.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor)
		])
	}
}

private class VaultSuccessFooterView: UIView {
	private lazy var textView: UITextView = {
		let textView = UITextView()
		textView.backgroundColor = .clear
		textView.isEditable = false
		textView.isScrollEnabled = false

		let text = NSMutableAttributedString(string: NSLocalizedString("addVault.success.footer", comment: ""), attributes: [NSAttributedString.Key.foregroundColor: UIColor.secondaryLabel])
		text.append(NSAttributedString(string: " "))
		let learnMoreLink = NSAttributedString(string: NSLocalizedString("common.footer.learnMore", comment: ""), attributes: [NSAttributedString.Key.link: URL(string: "https://cryptomator.org")!]) // TODO: replace link
		text.append(learnMoreLink)
		textView.attributedText = text
		textView.isUserInteractionEnabled = true
		textView.font = .preferredFont(forTextStyle: .footnote)

		return textView
	}()

	convenience init() {
		self.init(frame: .zero)
		textView.translatesAutoresizingMaskIntoConstraints = false
		addSubview(textView)

		NSLayoutConstraint.activate([
			textView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
			textView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
			textView.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
			textView.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor)
		])
	}
}

#if DEBUG
import SwiftUI

struct AddVaultSuccessVCPreview: PreviewProvider {
	static var previews: some View {
		AddVaultSuccessViewController(vaultName: "Work").toPreview()
	}
}
#endif
