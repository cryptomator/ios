//
//  CreateNewFolderViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 17.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Combine
import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import Foundation
import Promises

protocol CreateNewFolderViewModelProtocol: SingleSectionTableViewModel, ReturnButtonSupport {
	func createFolder() -> Promise<CloudPath>
}

class CreateNewFolderViewModel: SingleSectionTableViewModel, CreateNewFolderViewModelProtocol {
	var lastReturnButtonPressed: AnyPublisher<Void, Never> {
		return setupReturnButtonSupport(for: [folderNameCellViewModel], subscribers: &subscribers)
	}

	override var cells: [TableViewCellViewModel] {
		return [folderNameCellViewModel]
	}

	override var title: String? {
		return LocalizedString.getValue("common.button.createFolder")
	}

	let folderNameCellViewModel = TextFieldCellViewModel(type: .normal, isInitialFirstResponder: true)
	var folderName: String {
		return folderNameCellViewModel.input.value
	}

	private let parentPath: CloudPath
	private let provider: CloudProvider
	private lazy var subscribers = Set<AnyCancellable>()

	init(parentPath: CloudPath, provider: CloudProvider) {
		self.parentPath = parentPath
		self.provider = LocalizedCloudProviderDecorator(delegate: provider)
	}

	func createFolder() -> Promise<CloudPath> {
		guard !folderName.isEmpty else {
			return Promise(CreateNewFolderViewModelError.emptyFolderName)
		}
		let folderPath = parentPath.appendingPathComponent(folderName)
		return provider.createFolder(at: folderPath).then {
			folderPath
		}
	}

	override func getHeaderTitle(for section: Int) -> String? {
		guard section == 0 else {
			return nil
		}
		return LocalizedString.getValue("chooseFolder.createNewFolder.header.title")
	}
}

enum CreateNewFolderViewModelError: LocalizedError {
	case emptyFolderName

	var errorDescription: String? {
		switch self {
		case .emptyFolderName:
			return LocalizedString.getValue("chooseFolder.createNewFolder.error.emptyFolderName")
		}
	}
}
