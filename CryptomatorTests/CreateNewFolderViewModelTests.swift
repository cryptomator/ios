//
//  CreateNewFolderViewModelTests.swift
//  CryptomatorTests
//
//  Created by Philipp Schmid on 18.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Promises
import XCTest
@testable import Cryptomator

class CreateNewFolderViewModelTests: XCTestCase {
	private var cloudProviderMock: CloudProviderMockOld!
	var viewModel: CreateNewFolderViewModel!

	override func setUpWithError() throws {
		cloudProviderMock = CloudProviderMockOld()
		viewModel = CreateNewFolderViewModel(parentPath: CloudPath("/"), provider: cloudProviderMock)
	}

	func testCreateNewFolder() throws {
		let expectation = XCTestExpectation()
		setFolderName("Foo")
		viewModel.createFolder().then { folderPath in
			let expectedFolderPath = CloudPath("/Foo")
			XCTAssertEqual(expectedFolderPath, folderPath)
			XCTAssertEqual(1, self.cloudProviderMock.createdFolders.count)
			XCTAssertEqual(expectedFolderPath, self.cloudProviderMock.createdFolders[0])
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testCreateNewFolderForEmptyFolderName() throws {
		let expectation = XCTestExpectation()
		XCTAssert(viewModel.folderName.isEmpty)
		viewModel.createFolder().then { _ in
			XCTFail("Promise fulfilled")
		}.catch { error in
			XCTAssertEqual(0, self.cloudProviderMock.createdFolders.count)
			guard case CreateNewFolderViewModelError.emptyFolderName = error else {
				XCTFail("Promise rejected with wrong error: \(error)")
				return
			}
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testReturnButtonSupport() {
		let folderNameCellViewModel = viewModel.folderNameCellViewModel
		XCTAssert(folderNameCellViewModel.isInitialFirstResponder)
		let lastReturnButtonPressedRecorder = viewModel.lastReturnButtonPressed.recordNext(1)
		folderNameCellViewModel.returnButtonPressed()
		wait(for: lastReturnButtonPressedRecorder)
	}

	func setFolderName(_ name: String) {
		viewModel.folderNameCellViewModel.input.value = name
	}
}

private class CloudProviderMockOld: CloudProvider {
	var createdFolders = [CloudPath]()
	func fetchItemMetadata(at cloudPath: CloudPath) -> Promise<CloudItemMetadata> {
		return Promise(CloudProviderError.noInternetConnection)
	}

	func fetchItemList(forFolderAt cloudPath: CloudPath, withPageToken pageToken: String?) -> Promise<CloudItemList> {
		return Promise(CloudProviderError.noInternetConnection)
	}

	func downloadFile(from cloudPath: CloudPath, to localURL: URL, onTaskCreation: ((URLSessionDownloadTask?) -> Void)?) -> Promise<Void> {
		return Promise(CloudProviderError.noInternetConnection)
	}

	func uploadFile(from localURL: URL, to cloudPath: CloudPath, replaceExisting: Bool, onTaskCreation: ((URLSessionUploadTask?) -> Void)?) -> Promise<CloudItemMetadata> {
		return Promise(CloudProviderError.noInternetConnection)
	}

	func createFolder(at cloudPath: CloudPath) -> Promise<Void> {
		if createdFolders.contains(cloudPath) {
			return Promise(CloudProviderError.itemAlreadyExists)
		}
		createdFolders.append(cloudPath)
		return Promise(())
	}

	func deleteFile(at cloudPath: CloudPath) -> Promise<Void> {
		return Promise(CloudProviderError.noInternetConnection)
	}

	func deleteFolder(at cloudPath: CloudPath) -> Promise<Void> {
		return Promise(CloudProviderError.noInternetConnection)
	}

	func moveFile(from sourceCloudPath: CloudPath, to targetCloudPath: CloudPath) -> Promise<Void> {
		return Promise(CloudProviderError.noInternetConnection)
	}

	func moveFolder(from sourceCloudPath: CloudPath, to targetCloudPath: CloudPath) -> Promise<Void> {
		return Promise(CloudProviderError.noInternetConnection)
	}
}
