//
//  UIView+Preview.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 11.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

#if canImport(SwiftUI) && DEBUG
import SwiftUI
import UIKit

@available(iOS 13, *)
extension UIView {
	private struct Preview: UIViewRepresentable {
		// this variable is used for injecting the current view controller
		let view: UIView

		func makeUIView(context: Context) -> some UIView {
			return view
		}

		func updateUIView(_ uiView: UIViewType, context: Context) {}
	}

	func toPreview() -> some View {
		// inject self (the current view controller) for the preview
		Preview(view: self)
	}
}
#endif
