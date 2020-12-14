//
//  ViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 27.04.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CloudAccessPrivateCore
import UIKit

class ViewController: UIViewController {
	override func loadView() {
		let rootView = RootView()
		rootView.webdav.addTarget(self, action: #selector(webdav), for: .touchUpInside)
		rootView.logs.addTarget(self, action: #selector(logs), for: .touchUpInside)
		view = rootView
	}

	@objc func webdav() {
		navigationController?.pushViewController(WebDAVLoginViewController(), animated: true)
	}

	@objc func logs() {
		guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: CryptomatorConstants.appGroupName) else {
			print("containerURL is nil")
			return
		}
		let logDirectory = containerURL.appendingPathComponent("Logs")
		let activityController = UIActivityViewController(activityItems: [logDirectory], applicationActivities: nil)
		present(activityController, animated: true)
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		// Do any additional setup after loading the view.
	}
}

class RootView: UIView {
	let webdav = UIButton()
	let logs = UIButton()

	convenience init() {
		self.init(frame: CGRect.zero)
		backgroundColor = .white
		webdav.translatesAutoresizingMaskIntoConstraints = false
		logs.translatesAutoresizingMaskIntoConstraints = false

		addSubview(webdav)
		addSubview(logs)

		NSLayoutConstraint.activate([
			webdav.centerXAnchor.constraint(equalTo: centerXAnchor),
			webdav.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 50),

			webdav.widthAnchor.constraint(equalToConstant: 200),
			webdav.heightAnchor.constraint(equalToConstant: 100)
		])

		NSLayoutConstraint.activate([
			logs.centerXAnchor.constraint(equalTo: centerXAnchor),
			logs.topAnchor.constraint(equalTo: webdav.bottomAnchor, constant: 10),

			logs.widthAnchor.constraint(equalToConstant: 200),
			logs.heightAnchor.constraint(equalToConstant: 50)
		])

		webdav.backgroundColor = .blue
		webdav.setTitle("WebDAV", for: .normal)

		logs.backgroundColor = .green
		logs.setTitle("Logs", for: .normal)
	}
}
