//
//  ShareVaultViewController.swift
//  Cryptomator
//
//  Created by Majid Achhoud on 24.10.25.
//  Copyright © 2025 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import SwiftUI
import UIKit

/**
 ViewController for the `ShareVaultView`.

 This ViewController builds the bridge between UIKit and the SwiftUI `ShareVaultView`.
 This bridge is needed to integrate the SwiftUI view within a UIKit `UINavigationController`.
 */
class ShareVaultViewController: UIViewController {
	weak var coordinator: ShareVaultCoordinator?
	private let viewModel: ShareVaultViewModel

	init(viewModel: ShareVaultViewModel) {
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
		setupSwiftUIView()
	}

	private func setupSwiftUIView() {
		let child = UIHostingController(rootView: ShareVaultView(viewModel: viewModel))
		addChild(child)
		view.addSubview(child.view)
		child.didMove(toParent: self)
		child.view.translatesAutoresizingMaskIntoConstraints = false
		NSLayoutConstraint.activate(child.view.constraints(equalTo: view))
	}
}
