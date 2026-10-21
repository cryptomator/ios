//
//  CreateNewFolderViewModelTests.swift
//  CryptomatorTests
//
//  Created by Philipp Schmid on 18.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import os
import XCTest
@testable import Cryptomator

@MainActor
class CreateNewFolderViewModelTests: XCTestCase {
	private var cloudProviderMock: CloudProviderMockOld!
	var viewModel: CreateNewFolderViewModel!

	override func setUp() async throws {
		try await super.setUp()
		cloudProviderMock = CloudProviderMockOld()
		viewModel = CreateNewFolderViewModel(parentPath: CloudPath("/"), provider: cloudProviderMock)
	}

	func testCreateNewFolder() async throws {
		setFolderName("Foo")
		let folderPath = try await viewModel.createFolder()
		let expectedFolderPath = CloudPath("/Foo")
		XCTAssertEqual(expectedFolderPath, folderPath)
		XCTAssertEqual(1, cloudProviderMock.createdFolders.count)
		XCTAssertEqual(expectedFolderPath, cloudProviderMock.createdFolders[0])
	}

	func testCreateNewFolderForEmptyFolderName() async {
		XCTAssert(viewModel.folderName.isEmpty)
		await XCTAssertThrowsAsyncError(try await viewModel.createFolder()) { error in
			guard case CreateNewFolderViewModelError.emptyFolderName = error else {
				XCTFail("Threw wrong error: \(error)")
				return
			}
		}
		XCTAssertEqual(0, cloudProviderMock.createdFolders.count)
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

private final class CloudProviderMockOld: CloudProvider {
	private let createdFoldersState = OSAllocatedUnfairLock(initialState: [CloudPath]())

	var createdFolders: [CloudPath] {
		createdFoldersState.withLock { $0 }
	}

	@concurrent
	func fetchItemMetadata(at cloudPath: CloudPath) async throws -> CloudItemMetadata {
		throw CloudProviderError.noInternetConnection
	}

	@concurrent
	func fetchItemList(forFolderAt cloudPath: CloudPath, withPageToken pageToken: String?) async throws -> CloudItemList {
		throw CloudProviderError.noInternetConnection
	}

	@concurrent
	func downloadFile(from cloudPath: CloudPath, to localURL: URL, progress: Progress?, onTaskCreation: (@concurrent @Sendable (URLSessionDownloadTask) async -> Void)?) async throws -> CloudItemMetadata {
		throw CloudProviderError.noInternetConnection
	}

	@concurrent
	func uploadFile(from localURL: URL, to cloudPath: CloudPath, replaceExisting: Bool, progress: Progress?, onTaskCreation: (@concurrent @Sendable (URLSessionUploadTask) async -> Void)?) async throws -> CloudItemMetadata {
		throw CloudProviderError.noInternetConnection
	}

	@concurrent
	func createFolder(at cloudPath: CloudPath) async throws {
		try createdFoldersState.withLock { createdFolders in
			if createdFolders.contains(cloudPath) {
				throw CloudProviderError.itemAlreadyExists
			}
			createdFolders.append(cloudPath)
		}
	}

	@concurrent
	func deleteFile(at cloudPath: CloudPath) async throws {
		throw CloudProviderError.noInternetConnection
	}

	@concurrent
	func deleteFolder(at cloudPath: CloudPath) async throws {
		throw CloudProviderError.noInternetConnection
	}

	@concurrent
	func moveFile(from sourceCloudPath: CloudPath, to targetCloudPath: CloudPath) async throws {
		throw CloudProviderError.noInternetConnection
	}

	@concurrent
	func moveFolder(from sourceCloudPath: CloudPath, to targetCloudPath: CloudPath) async throws {
		throw CloudProviderError.noInternetConnection
	}
}
