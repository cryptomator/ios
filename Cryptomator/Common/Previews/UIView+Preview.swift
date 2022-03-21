//
//  UIView+Preview.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 11.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import SwiftUI
import UIKit

extension UIView {
	private struct Preview: UIViewRepresentable {
		// this variable is used for injecting the current view
		let view: UIView

		func makeUIView(context: Context) -> some UIView {
			return view
		}

		func updateUIView(_ uiView: UIViewType, context: Context) {}
	}

	func toPreview() -> some View {
		// inject self (the current view) for the preview
		Preview(view: self)
	}
}
