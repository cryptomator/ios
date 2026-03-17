//
//  VaultListViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 04.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import Combine
import CryptomatorCommonCore
import Dependencies
import Foundation
import UIKit

class VaultListViewController: ListViewController<VaultCellViewModel> {
	weak var coordinator: MainCoordinator?

	private let viewModel: VaultListViewModelProtocol
	private var willEnterForegroundObserver: NSObjectProtocol?
	@Dependency(\.fullVersionChecker) private var fullVersionChecker

	#if !ALWAYS_PREMIUM
	private var tenthAnniversaryBannerView: UIView?
	private var fullVersionPurchasedObserver: NSObjectProtocol?
	#endif

	init(with viewModel: VaultListViewModelProtocol) {
		self.viewModel = viewModel
		super.init(viewModel: viewModel)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		title = "Cryptomator"
		let settingsSymbol = UIImage(systemName: "gearshape")
		let settingsButton = UIBarButtonItem(image: settingsSymbol, style: .plain, target: self, action: #selector(showSettings))
		navigationItem.leftBarButtonItem = settingsButton
		let addNewVaulButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addNewVault))
		navigationItem.rightBarButtonItem = addNewVaulButton

		willEnterForegroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
			self?.viewModel.refreshVaultLockStates().catch { error in
				DDLogError("Refresh vault lock states failed with error: \(error)")
			}
		}

		#if !ALWAYS_PREMIUM
		fullVersionPurchasedObserver = NotificationCenter.default.addObserver(forName: .purchasedFullVersionNotification, object: nil, queue: .main) { [weak self] _ in
			self?.dismissTenthAnniversaryBanner()
		}
		if SalePromo.shared.shouldShowTenthAnniversaryBanner() {
			showTenthAnniversaryBanner()
		}
		#endif
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		viewModel.refreshVaultLockStates().catch { error in
			DDLogError("Refresh vault lock states failed with error: \(error)")
		}
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		if CryptomatorUserDefaults.shared.showOnboardingAtStartup {
			coordinator?.showOnboarding()
		} else if fullVersionChecker.hasExpiredTrial, !CryptomatorUserDefaults.shared.showedTrialExpiredAtStartup {
			coordinator?.showTrialExpired()
		}
	}

	override func registerCells() {
		tableView.register(VaultCell.self, forCellReuseIdentifier: "VaultCell")
	}

	override func configureDataSource() {
		dataSource = EditableDataSource<Section, VaultCellViewModel>(tableView: tableView, cellProvider: { tableView, _, cellViewModel in
			let cell = tableView.dequeueReusableCell(withIdentifier: "VaultCell") as? VaultCell
			cell?.configure(with: cellViewModel)
			return cell
		})
	}

	override func setEditing(_ editing: Bool, animated: Bool) {
		super.setEditing(editing, animated: animated)
		header.isEditing = editing
	}

	override func removeRow(at indexPath: IndexPath) throws {
		guard let vaultCellViewModel = dataSource?.itemIdentifier(for: indexPath) else {
			return
		}
		try super.removeRow(at: indexPath)
		coordinator?.removedVault(vaultCellViewModel.vault)
	}

	@objc func addNewVault() {
		setEditing(false, animated: true)
		coordinator?.addVault()
	}

	@objc func showSettings() {
		setEditing(false, animated: true)
		coordinator?.showSettings()
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		super.tableView(tableView, didSelectRowAt: indexPath)
		if let vaultCellViewModel = dataSource?.itemIdentifier(for: indexPath) {
			coordinator?.showVaultDetail(for: vaultCellViewModel.vault)
		}
	}

	// MARK: - Sale Promo Banner

	#if !ALWAYS_PREMIUM
	private func showTenthAnniversaryBanner() {
		let banner = UIView()
		banner.backgroundColor = UIColor.cryptomatorPrimary
		banner.translatesAutoresizingMaskIntoConstraints = false
		banner.layer.cornerRadius = 12
		banner.layer.masksToBounds = true

		let emojiLabel = UILabel()
		emojiLabel.text = SalePromo.tenthAnniversaryEmoji
		emojiLabel.translatesAutoresizingMaskIntoConstraints = false
		emojiLabel.setContentHuggingPriority(.required, for: .horizontal)
		emojiLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

		let textLabel = UILabel()
		textLabel.text = "Lifetime License is \(SalePromo.tenthAnniversaryDiscount)!"
		textLabel.textColor = .white
		textLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
		textLabel.adjustsFontSizeToFitWidth = true
		textLabel.minimumScaleFactor = 0.5
		textLabel.numberOfLines = 2
		textLabel.translatesAutoresizingMaskIntoConstraints = false

		let dismissButton = UIButton(type: .close)
		dismissButton.addTarget(self, action: #selector(dismissTenthAnniversaryBanner), for: .touchUpInside)
		dismissButton.translatesAutoresizingMaskIntoConstraints = false
		dismissButton.setContentHuggingPriority(.required, for: .horizontal)
		dismissButton.setContentCompressionResistancePriority(.required, for: .horizontal)

		banner.addSubview(emojiLabel)
		banner.addSubview(textLabel)
		banner.addSubview(dismissButton)

		NSLayoutConstraint.activate([
			emojiLabel.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 16),
			emojiLabel.centerYAnchor.constraint(equalTo: banner.centerYAnchor),

			textLabel.leadingAnchor.constraint(equalTo: emojiLabel.trailingAnchor, constant: 8),
			textLabel.centerYAnchor.constraint(equalTo: banner.centerYAnchor),

			dismissButton.leadingAnchor.constraint(equalTo: textLabel.trailingAnchor, constant: 8),
			dismissButton.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -16),
			dismissButton.centerYAnchor.constraint(equalTo: banner.centerYAnchor)
		])

		let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(tenthAnniversaryBannerTapped))
		banner.addGestureRecognizer(tapGestureRecognizer)

		view.addSubview(banner)

		NSLayoutConstraint.activate([
			banner.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
			banner.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
			banner.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
			banner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
			banner.heightAnchor.constraint(equalToConstant: 50)
		])

		tenthAnniversaryBannerView = banner
	}

	@objc private func dismissTenthAnniversaryBanner() {
		UIView.animate(withDuration: 0.3, animations: {
			self.tenthAnniversaryBannerView?.alpha = 0
		}, completion: { _ in
			self.tenthAnniversaryBannerView?.removeFromSuperview()
			self.tenthAnniversaryBannerView = nil
		})
		CryptomatorUserDefaults.shared.tenthAnniversaryBannerDismissed = true
	}

	@objc private func tenthAnniversaryBannerTapped() {
		coordinator?.showPurchase()
	}
	#endif
}

extension Notification.Name {
	static let purchasedFullVersionNotification = Notification.Name("PurchasedFullVersionNotification")
}
