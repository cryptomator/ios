//
//  UIViewController+Preview.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 04.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import SwiftUI
import UIKit

extension UIViewController {
	private struct Preview: UIViewControllerRepresentable {
		// this variable is used for injecting the current view controller
		let viewController: UIViewController

		func makeUIViewController(context: Context) -> UIViewController {
			return viewController
		}

		func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
	}

	public func toPreview() -> some View {
		// inject self (the current view controller) for the preview
		Preview(viewController: self)
	}
}
