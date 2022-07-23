//
//  HubVaultViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 21.07.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import Combine
import SwiftUI
import UIKit

public class HubVaultViewController: UIHostingController<AddHubVaultView> {
	let viewModel: HubVaultViewModel
	private var subscriber: AnyCancellable?
	private weak var coordinator: Coordinator?

	public init(viewModel: HubVaultViewModel) {
		self.viewModel = viewModel
		self.coordinator = viewModel.coordinator as? Coordinator
		super.init(rootView: .init(viewModel: viewModel))
	}

	@available(*, unavailable)
	@MainActor dynamic required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override public func viewDidLoad() {
		super.viewDidLoad()
		subscriber = viewModel.$error.receive(on: DispatchQueue.main).compactMap { $0 }.sink { [weak self] error in
			if let self = self {
				self.coordinator?.handleError(error, for: self)
			}
		}
	}
}
