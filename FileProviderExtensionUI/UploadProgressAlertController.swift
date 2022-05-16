//
//  UploadProgressAlertController.swift
//  FileProviderExtensionUI
//
//  Created by Philipp Schmid on 09.05.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import Promises
import UIKit

class UploadProgressAlertController: UIAlertController {
	/// Promise fulfills as soon as a alert action gets triggered
	let alertActionTriggered = Promise<Void>.pending()

	var progress: Double? {
		didSet {
			DispatchQueue.main.async {
				if let progress = self.progress {
					self.setMessage(with: progress)
				} else {
					self.setMessageForMissingProgress()
				}
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

	func observeProgress(itemIdentifier: NSFileProviderItemIdentifier, proxy: UploadRetrying) -> Promise<Void> {
		return Promise<Void> { fulfill, _ in
			Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
				let isVisible = self?.viewIfLoaded?.window != nil
				if isVisible {
					proxy.getCurrentFractionalUploadProgress(for: itemIdentifier) { number in
						let currentProgress = number?.doubleValue
						self?.progress = currentProgress
						if let progress = currentProgress, progress >= 1.0 {
							timer.invalidate()
							fulfill(())
						}
					}
				} else {
					timer.invalidate()
				}
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
