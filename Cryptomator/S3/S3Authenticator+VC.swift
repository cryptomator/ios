//
//  S3Authenticator+VC.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 28.06.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import UIKit

extension S3Authenticator {
	@MainActor private static var coordinator: S3AuthenticationCoordinator?

	static func authenticate(from viewController: UIViewController) async throws -> S3Credential {
		let navigationController = BaseNavigationController()
		let s3Coordinator = S3AuthenticationCoordinator(navigationController: navigationController)
		coordinator = s3Coordinator
		defer {
			coordinator = nil
		}
		viewController.present(navigationController, animated: true)
		s3Coordinator.start()
		return try await s3Coordinator.pendingAuthentication.value
	}
}

class S3AuthenticationCoordinator: Coordinator, S3Authenticating {
	let pendingAuthentication = OneShotSignal<S3Credential>()
	var navigationController: UINavigationController
	var childCoordinators = [Coordinator]()
	weak var parentCoordinator: Coordinator?

	init(navigationController: UINavigationController) {
		self.navigationController = navigationController
	}

	func start() {
		let viewController = S3AuthenticationViewController(viewModel: .init())
		viewController.coordinator = self
		navigationController.pushViewController(viewController, animated: false)
	}

	func authenticated(with credential: S3Credential) {
		pendingAuthentication.fulfill(credential)
		close()
	}

	func cancel() {
		pendingAuthentication.reject(CocoaError(.userCancelled))
		close()
	}

	private func close() {
		navigationController.dismiss(animated: true)
		parentCoordinator?.childDidFinish(self)
	}
}

class S3CredentialCoordinator: Coordinator, S3Authenticating {
	var navigationController: UINavigationController
	var childCoordinators = [Coordinator]()
	weak var parentCoordinator: Coordinator?
	private let credential: S3Credential
	private let displayName: String

	init(credential: S3Credential, displayName: String, navigationController: UINavigationController) {
		self.credential = credential
		self.displayName = displayName
		self.navigationController = navigationController
	}

	func start() {
		let viewController = S3AuthenticationViewController(viewModel: .init(displayName: displayName, credential: credential))
		viewController.coordinator = self
		navigationController.pushViewController(viewController, animated: false)
	}

	func authenticated(with credential: S3Credential) {
		close()
	}

	func cancel() {
		close()
	}

	private func close() {
		navigationController.dismiss(animated: true)
		parentCoordinator?.childDidFinish(self)
	}
}
