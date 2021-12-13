//
//  DetectedVaultFailureViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 28.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import UIKit

class DetectedVaultFailureViewController: UIViewController {
	override func viewDidLoad() {
		super.viewDidLoad()
		let failureView = DetectedVaultFailureView(text: LocalizedString.getValue("addVault.createNewVault.detectedMasterkey.text"))
		let containerView = UIView()
		containerView.backgroundColor = .systemGroupedBackground
		view.addSubview(containerView)
		failureView.translatesAutoresizingMaskIntoConstraints = false
		containerView.translatesAutoresizingMaskIntoConstraints = false
		containerView.addSubview(failureView)
		NSLayoutConstraint.activate([
			containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
			containerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
			containerView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
			containerView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),

			failureView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
			failureView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
			failureView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
			failureView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
		])
	}
}

#if DEBUG
import SwiftUI

struct DetectedVaultFailureVC_Preview: PreviewProvider {
	static var previews: some View {
		DetectedVaultFailureViewController().toPreview()
	}
}
#endif
