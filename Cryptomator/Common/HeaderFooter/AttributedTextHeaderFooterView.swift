//
//  AttributedTextHeaderFooterView.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 05.08.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Combine
import UIKit

class AttributedTextHeaderFooterView: UITableViewHeaderFooterView, HeaderFooterViewModelConfiguring {
	private var subscriber = Set<AnyCancellable>()
	lazy var textView: UITextView = {
		let textView = UITextView()
		textView.backgroundColor = .clear
		textView.isEditable = false
		textView.isScrollEnabled = false
		textView.isUserInteractionEnabled = true
		textView.textContainerInset = .zero
		textView.textContainer.lineFragmentPadding = 0
		return textView
	}()

	weak var tableView: UITableView?

	init() {
		super.init(reuseIdentifier: nil)

		textView.translatesAutoresizingMaskIntoConstraints = false
		contentView.addSubview(textView)
		NSLayoutConstraint.activate([
			textView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
			textView.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
			textView.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
			textView.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor)
		])
		// Bind to own textLabel as the text color and font are set automatically by the UITableView later and there is no other way to access these internal values.
		textLabel?.publisher(for: \.textColor).sink(receiveValue: { [weak self] textColor in
			self?.textView.textColor = textColor
		}).store(in: &subscriber)
		textLabel?.publisher(for: \.font).sink(receiveValue: { [weak self] font in
			self?.textView.font = font
		}).store(in: &subscriber)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func configure(with viewModel: HeaderFooterViewModel) {
		guard let viewModel = viewModel as? AttributedTextHeaderFooterViewModel else {
			return
		}
		viewModel.attributedText.$value.receive(on: DispatchQueue.main).sink(receiveValue: { [weak self] attributedText in
			UIView.setAnimationsEnabled(false)
			self?.tableView?.performBatchUpdates({
				self?.textView.attributedText = attributedText
				self?.textView.font = self?.textLabel?.font
				self?.textView.textColor = self?.textLabel?.textColor
			})
			UIView.setAnimationsEnabled(true)
		}).store(in: &subscriber)
	}
}
