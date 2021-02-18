//
//  FolderBrowserViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 09.11.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess
import Foundation
import UIKit

class FolderBrowserViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
	private let viewModel: FolderBrowserViewModel
	private var tableView: UITableView?
	init(viewModel: FolderBrowserViewModel) {
		self.viewModel = viewModel
		super.init(nibName: nil, bundle: nil)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func loadView() {
		let rootView = UIView()
		tableView = UITableView()
		tableView?.translatesAutoresizingMaskIntoConstraints = false
		rootView.addSubview(tableView!)
		NSLayoutConstraint.activate([
			tableView!.topAnchor.constraint(equalTo: rootView.topAnchor),
			tableView!.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),
			tableView!.leftAnchor.constraint(equalTo: rootView.leftAnchor),
			tableView!.rightAnchor.constraint(equalTo: rootView.rightAnchor)
		])
		view = rootView
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		let barHeight: CGFloat = UIApplication.shared.statusBarFrame.size.height
		let displayWidth: CGFloat = view.frame.width
		let displayHeight: CGFloat = view.frame.height
		tableView?.frame = CGRect(x: 0, y: barHeight, width: displayWidth, height: displayHeight - barHeight)
		tableView?.register(UITableViewCell.self, forCellReuseIdentifier: "MyCell")
		tableView?.dataSource = self
		tableView?.delegate = self
		viewModel.fetchItemList().then {
			self.tableView?.reloadData()
		}.catch { error in
			print(error)
		}
	}

	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		let vc = viewModel.didSelect(row: indexPath.row)
		navigationController?.pushViewController(vc, animated: true)
	}

	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return viewModel.items.count
	}

	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "MyCell", for: indexPath as IndexPath)
		cell.textLabel!.text = "\(viewModel.items[indexPath.row].name)"
		return cell
	}

	func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
		if indexPath.row >= viewModel.items.count {
			if !viewModel.isLoading, !viewModel.fetchedAllItems {
				print("load next item")
				viewModel.fetchItemList().then {
					self.tableView?.reloadData()
				}
			}
		}
	}
}
