//
//  LocalizedCloudProviderDecoratorTests.swift
//  CryptomatorCommonCoreTests
//
//  Created by Tobias Hagemann on 16.10.26.
//  Copyright © 2026 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import XCTest
@testable import CryptomatorCommonCore

class LocalizedCloudProviderDecoratorTests: XCTestCase {
	var cloudProviderMock: CloudProviderMock!
	var decorator: LocalizedCloudProviderDecorator!
	let cloudPath = CloudPath("/Folder/Item")
	let targetCloudPath = CloudPath("/Target/Item")
	let localURL = URL(fileURLWithPath: "/Local/Item")

	override func setUpWithError() throws {
		cloudProviderMock = CloudProviderMock()
		decorator = LocalizedCloudProviderDecorator(delegate: cloudProviderMock)
	}

	func testFetchItemMetadata() async {
		await assertLocalizesErrors(naming: cloudPath, setError: { self.cloudProviderMock.fetchItemMetadataAtThrowableError = $0 }, operation: {
			_ = try await self.decorator.fetchItemMetadata(at: self.cloudPath)
		})
	}

	func testFetchItemList() async {
		await assertLocalizesErrors(naming: cloudPath, setError: { self.cloudProviderMock.fetchItemListForFolderAtWithPageTokenThrowableError = $0 }, operation: {
			_ = try await self.decorator.fetchItemList(forFolderAt: self.cloudPath, withPageToken: nil)
		})
	}

	func testDownloadFile() async {
		let localPath = CloudPath(localURL.path)
		await assertLocalizesErrors(naming: cloudPath, overriding: [.itemAlreadyExists: localPath], setError: { self.cloudProviderMock.downloadFileFromToThrowableError = $0 }, operation: {
			_ = try await self.decorator.downloadFile(from: self.cloudPath, to: self.localURL, progress: nil, onTaskCreation: nil)
		})
	}

	func testDownloadFileForwardsProgressAndTaskCreationHook() async throws {
		cloudProviderMock.downloadFileFromToClosure = { cloudPath, _ in
			CloudItemMetadata(name: cloudPath.lastPathComponent, cloudPath: cloudPath, itemType: .file, lastModifiedDate: nil, size: nil)
		}
		let progress = Progress()
		let progressID = ObjectIdentifier(progress)
		let hookInvoked = XCTestExpectation(description: "Task creation hook invoked")

		_ = try await decorator.downloadFile(from: cloudPath, to: localURL, progress: progress, onTaskCreation: { _ in
			hookInvoked.fulfill()
		})

		XCTAssertEqual(progressID, cloudProviderMock.downloadFileFromToReceivedProgress.map(ObjectIdentifier.init))
		let receivedHook = try XCTUnwrap(cloudProviderMock.downloadFileFromToReceivedOnTaskCreation)
		try await receivedHook(URLSession.shared.downloadTask(with: XCTUnwrap(URL(string: "https://example.com/"))))
		await fulfillment(of: [hookInvoked], timeout: 1.0)
	}

	func testUploadFile() async {
		let localPath = CloudPath(localURL.path)
		await assertLocalizesErrors(naming: cloudPath, overriding: [.itemNotFound: localPath, .itemTypeMismatch: localPath], setError: { self.cloudProviderMock.uploadFileFromToReplaceExistingThrowableError = $0 }, operation: {
			_ = try await self.decorator.uploadFile(from: self.localURL, to: self.cloudPath, replaceExisting: false, progress: nil, onTaskCreation: nil)
		})
	}

	func testUploadFileForwardsProgressAndTaskCreationHook() async throws {
		cloudProviderMock.uploadFileFromToReplaceExistingClosure = { _, cloudPath, _ in
			CloudItemMetadata(name: cloudPath.lastPathComponent, cloudPath: cloudPath, itemType: .file, lastModifiedDate: nil, size: nil)
		}
		let progress = Progress()
		let progressID = ObjectIdentifier(progress)
		let hookInvoked = XCTestExpectation(description: "Task creation hook invoked")

		_ = try await decorator.uploadFile(from: localURL, to: cloudPath, replaceExisting: false, progress: progress, onTaskCreation: { _ in
			hookInvoked.fulfill()
		})

		XCTAssertEqual(progressID, cloudProviderMock.uploadFileFromToReplaceExistingReceivedProgress.map(ObjectIdentifier.init))
		let receivedHook = try XCTUnwrap(cloudProviderMock.uploadFileFromToReplaceExistingReceivedOnTaskCreation)
		try await receivedHook(URLSession.shared.uploadTask(with: URLRequest(url: XCTUnwrap(URL(string: "https://example.com/"))), from: Data()))
		await fulfillment(of: [hookInvoked], timeout: 1.0)
	}

	func testCreateFolder() async {
		await assertLocalizesErrors(naming: cloudPath, setError: { self.cloudProviderMock.createFolderAtThrowableError = $0 }, operation: {
			try await self.decorator.createFolder(at: self.cloudPath)
		})
	}

	func testDeleteFile() async {
		await assertLocalizesErrors(naming: cloudPath, setError: { self.cloudProviderMock.deleteFileAtThrowableError = $0 }, operation: {
			try await self.decorator.deleteFile(at: self.cloudPath)
		})
	}

	func testDeleteFolder() async {
		await assertLocalizesErrors(naming: cloudPath, setError: { self.cloudProviderMock.deleteFolderAtThrowableError = $0 }, operation: {
			try await self.decorator.deleteFolder(at: self.cloudPath)
		})
	}

	func testMoveFile() async {
		await assertLocalizesErrors(naming: cloudPath, overriding: [.itemAlreadyExists: targetCloudPath, .parentFolderDoesNotExist: targetCloudPath], setError: { self.cloudProviderMock.moveFileFromToThrowableError = $0 }, operation: {
			try await self.decorator.moveFile(from: self.cloudPath, to: self.targetCloudPath)
		})
	}

	func testMoveFolder() async {
		await assertLocalizesErrors(naming: cloudPath, overriding: [.itemAlreadyExists: targetCloudPath, .parentFolderDoesNotExist: targetCloudPath], setError: { self.cloudProviderMock.moveFolderFromToThrowableError = $0 }, operation: {
			try await self.decorator.moveFolder(from: self.cloudPath, to: self.targetCloudPath)
		})
	}

	private func assertLocalizesErrors(naming defaultPath: CloudPath,
	                                   overriding overriddenPaths: [CloudProviderError: CloudPath] = [:],
	                                   setError: (Error) -> Void,
	                                   operation: () async throws -> Void,
	                                   file: StaticString = #filePath,
	                                   line: UInt = #line) async {
		func path(for error: CloudProviderError) -> CloudPath {
			overriddenPaths[error] ?? defaultPath
		}
		let expectedErrors: [(CloudProviderError, LocalizedCloudProviderError)] = [
			(.itemNotFound, .itemNotFound(cloudPath: path(for: .itemNotFound))),
			(.itemAlreadyExists, .itemAlreadyExists(cloudPath: path(for: .itemAlreadyExists))),
			(.itemTypeMismatch, .itemTypeMismatch(cloudPath: path(for: .itemTypeMismatch))),
			(.parentFolderDoesNotExist, .parentFolderDoesNotExist(cloudPath: path(for: .parentFolderDoesNotExist))),
			(.pageTokenInvalid, .pageTokenInvalid),
			(.quotaInsufficient, .quotaInsufficient),
			(.unauthorized, .unauthorized),
			(.noInternetConnection, .noInternetConnection)
		]
		for (cloudProviderError, expectedError) in expectedErrors {
			setError(cloudProviderError)
			await XCTAssertThrowsAsyncError(try await operation(), file: file, line: line) { error in
				guard let localizedError = error as? LocalizedCloudProviderError, isEqual(localizedError, expectedError) else {
					return XCTFail("\(cloudProviderError) was mapped to \(error) instead of \(expectedError)", file: file, line: line)
				}
			}
		}
		setError(CancellationError())
		await XCTAssertThrowsAsyncError(try await operation(), file: file, line: line) { error in
			XCTAssert(error is CancellationError, "CancellationError was mapped to \(error)", file: file, line: line)
		}
	}

	private func isEqual(_ lhs: LocalizedCloudProviderError, _ rhs: LocalizedCloudProviderError) -> Bool {
		switch (lhs, rhs) {
		case let (.itemNotFound(lhsPath), .itemNotFound(rhsPath)),
		     let (.itemAlreadyExists(lhsPath), .itemAlreadyExists(rhsPath)),
		     let (.itemTypeMismatch(lhsPath), .itemTypeMismatch(rhsPath)),
		     let (.parentFolderDoesNotExist(lhsPath), .parentFolderDoesNotExist(rhsPath)):
			return lhsPath == rhsPath
		case (.pageTokenInvalid, .pageTokenInvalid), (.quotaInsufficient, .quotaInsufficient), (.unauthorized, .unauthorized), (.noInternetConnection, .noInternetConnection):
			return true
		default:
			return false
		}
	}
}
