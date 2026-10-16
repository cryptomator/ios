//
//  UploadProgressAlertController.swift
//  FileProviderExtensionUI
//
//  Created by Philipp Schmid on 09.05.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import UIKit

class UploadProgressAlertController: UIAlertController {
	let alertActionTriggered = OneShotSignal<Void>()

	var progress: Double? {
		didSet {
			if let progress = progress {
				setMessage(with: progress)
			} else {
				setMessageForMissingProgress()
			}
		}
	}

	private lazy var formatter: NumberFormatter = {
		let formatter = NumberFormatter()
		formatter.minimumFractionDigits = 2
		formatter.maximumFractionDigits = 2
		formatter.numberStyle = .percent
		return formatter
	}()

	func setMessage(with progress: Double) {
		let formattedProgress = formatter.string(from: progress as NSNumber) ?? "n/a"
		message = String(format: LocalizedString.getValue("fileProvider.uploadProgress.message"), formattedProgress)
	}

	func setMessageForMissingProgress() {
		message = LocalizedString.getValue("fileProvider.uploadProgress.missing")
	}

	/**
	 Polls the upload progress every second until the upload finished or the alert is no longer visible.

	 Throws `CancellationError` as soon as the task is cancelled, even while an XPC reply is outstanding.
	 */
	func observeProgress(itemIdentifier: NSFileProviderItemIdentifier, proxy: UploadRetrying) async throws {
		while true {
			try await Task.sleep(for: .seconds(1))
			guard viewIfLoaded?.window != nil else {
				return
			}
			let currentProgress = try await proxy.getCurrentFractionalUploadProgress(for: itemIdentifier)
			progress = currentProgress
			if let currentProgress, currentProgress >= 1.0 {
				return
			}
		}
	}
}

enum RetryUploadAlertControllerFactory {
	static func createUploadProgressAlert(dismissAction: @escaping () -> Void, retryAction: @escaping () -> Void) -> UploadProgressAlertController {
		let alertController = UploadProgressAlertController(title: LocalizedString.getValue("fileProvider.uploadProgress.title"),
		                                                    message: LocalizedString.getValue("fileProvider.uploadProgress.connecting"),
		                                                    preferredStyle: .alert)
		let dismissAlertAction = UIAlertAction(title: LocalizedString.getValue("common.button.close"), style: .cancel) { _ in
			dismissAction()
			alertController.alertActionTriggered.fulfill(())
		}
		let retryAlertAction = UIAlertAction(title: LocalizedString.getValue("common.button.retry"), style: .default) { _ in
			retryAction()
			alertController.alertActionTriggered.fulfill(())
		}
		alertController.addAction(dismissAlertAction)
		alertController.addAction(retryAlertAction)
		alertController.preferredAction = dismissAlertAction
		return alertController
	}

	static func createDomainNotFoundAlert(okAction: @escaping () -> Void) -> UIAlertController {
		let alertController = UIAlertController(title: LocalizedString.getValue("common.alert.error.title"), message: LocalizedString.getValue("fileProvider.uploadProgress.missingDomainError"), preferredStyle: .alert)
		let okAlertAction = UIAlertAction(title: LocalizedString.getValue("common.button.ok"), style: .cancel) { _ in
			okAction()
		}
		alertController.addAction(okAlertAction)
		alertController.preferredAction = okAlertAction
		return alertController
	}
}
