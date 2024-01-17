//
//  LocalWebViewController.swift
//  Cryptomator
//
//  Created by Tobias Hagemann on 14.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import Foundation
import UIKit
import WebKit

class LocalWebViewController: UIViewController, WKNavigationDelegate {
	weak var coordinator: Coordinator?

	private let viewModel: LocalWebViewModel

	init(viewModel: LocalWebViewModel) {
		self.viewModel = viewModel
		super.init(nibName: nil, bundle: nil)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func loadView() {
		let webView = WKWebView(frame: .zero)
		webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		webView.navigationDelegate = self
		view = webView
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		title = viewModel.title
		view.isOpaque = false
		view.backgroundColor = .cryptomatorBackground
		do {
			let htmlString = try viewModel.loadHTMLString()
			guard let webView = view as? WKWebView else { return }
			webView.loadHTMLString(htmlString, baseURL: viewModel.baseURL)
		} catch {
			coordinator?.handleError(error, for: self)
		}
	}

	// MARK: - WKNavigationDelegate

	func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
		if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
			UIApplication.shared.open(url)
			decisionHandler(.cancel)
		} else {
			decisionHandler(.allow)
		}
	}
}
