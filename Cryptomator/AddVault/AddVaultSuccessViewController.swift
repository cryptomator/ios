//
//  AddVaultSuccessViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 30.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import UIKit
class AddVaultSuccessViewController: UITableViewController {
	let vaultName: String

	init(vaultName: String) {
		self.vaultName = vaultName
		super.init(nibName: nil, bundle: nil)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func loadView() {
		tableView = UITableView(frame: .zero, style: .grouped)
		let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))
		navigationItem.rightBarButtonItem = doneButton
	}

	override func viewDidLoad() {
		tableView.register(ButtonCell.self, forCellReuseIdentifier: "ButtonCell")
		tableView.rowHeight = 44
	}

	@objc func done() {
		#warning("TODO: Add Coordinator")
	}

	@objc func openFilesApp() {
		#warning("TODO: Add Coordinator")
	}

	// MARK: Table View

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		1
	}

	override func numberOfSections(in tableView: UITableView) -> Int {
		1
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "ButtonCell", for: indexPath) as! ButtonCell
		cell.button.setTitle("Open Files App", for: .normal)
		cell.button.addTarget(self, action: #selector(openFilesApp), for: .touchUpInside)
		return cell
	}

	override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		return VaultSuccessHeaderView(vaultName: vaultName)
	}

	override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
		VaultSuccessFooterView()
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
		infoText.text = "Added Vault \"\(vaultName)\".\n Access this vault via the Files app."
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
		let textColor: UIColor
		if #available(iOS 13.0, *) {
			textColor = .secondaryLabel
		} else {
			textColor = UIColor(named: "secondaryLabel")!
		}

		let text = NSMutableAttributedString(string: "If you haven't already, enable Cryptomator in the files app. ", attributes: [NSAttributedString.Key.foregroundColor: textColor])
		let learnMoreLink = NSMutableAttributedString(string: "Learn more.", attributes: [NSAttributedString.Key.link: URL(string: "https://www.cryptomator.de")!])
		learnMoreLink.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor(named: "primary")!, range: NSRange(location: 0, length: learnMoreLink.length))
		text.append(learnMoreLink)
		textView.attributedText = text
		textView.linkTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor(named: "primary")!]
		textView.isUserInteractionEnabled = true
		textView.font = .systemFont(ofSize: 17)

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

#if canImport(SwiftUI) && DEBUG
import SwiftUI

@available(iOS 13, *)
struct AddVaultSuccessVCPreview: PreviewProvider {
	static var previews: some View {
		AddVaultSuccessViewController(vaultName: "Work").toPreview()
	}
}
#endif
