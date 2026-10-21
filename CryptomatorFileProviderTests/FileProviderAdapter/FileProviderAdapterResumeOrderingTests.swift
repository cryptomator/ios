//
//  FileProviderAdapterResumeOrderingTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Tobias Hagemann on 17.06.26.
//  Copyright © 2026 Skymatic GmbH. All rights reserved.
//

import FileProvider
import Foundation
import XCTest
@testable import CryptomatorCommonCore
@testable import CryptomatorFileProvider

/// The provider resumes a WebDAV transfer task once the task creation hook returns, so the hook must not return before
/// `NSFileProviderManager.register(_:forItemWithIdentifier:)` completes. Otherwise the transfer starts before the system
/// tracks it, which loses progress reporting and can leave the File Provider hanging (issue #449).
/// A failed registration must still let the hook return, so a transfer is never silently dropped (issue #272).
/// The app never resumes the task itself.
final class FileProviderAdapterResumeOrderingTests: FileProviderAdapterTestCase {
	private let downloadIdentifier = NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: 2)
	private let uploadIdentifier = NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: 3)
	private let session = URLSession(configuration: .ephemeral)

	override func setUp() async throws {
		try await super.setUp()
		metadataManagerMock.cachedMetadata[2] = ItemMetadata(id: 2, name: "download.txt", type: .file, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		metadataManagerMock.cachedMetadata[3] = ItemMetadata(id: 3, name: "upload.txt", type: .file, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, isPlaceholderItem: false)
	}

	override func tearDown() async throws {
		session.invalidateAndCancel()
		try await super.tearDown()
	}

	// MARK: - Download

	func testDownloadHookReturnsOnlyAfterRegistrationCompletes() async throws {
		let hook = try await createDownloadHook()
		try await assertHookReturnsOnlyAfterRegistrationCompletes(hook, task: session.downloadTask(with: unreachableURL()), identifier: downloadIdentifier)
	}

	func testDownloadHookReturnsWhenRegistrationFails() async throws {
		let hook = try await createDownloadHook()
		try await assertHookReturnsWhenRegistrationFails(hook, task: session.downloadTask(with: unreachableURL()))
	}

	// MARK: - Upload

	func testUploadHookReturnsOnlyAfterRegistrationCompletes() async throws {
		let hook = try await createUploadHook()
		try await assertHookReturnsOnlyAfterRegistrationCompletes(hook, task: session.uploadTask(with: URLRequest(url: unreachableURL()), from: Data()), identifier: uploadIdentifier)
	}

	func testUploadHookReturnsWhenRegistrationFails() async throws {
		let hook = try await createUploadHook()
		try await assertHookReturnsWhenRegistrationFails(hook, task: session.uploadTask(with: URLRequest(url: unreachableURL()), from: Data()))
	}

	// MARK: - Helpers

	private func createDownloadHook() async throws -> URLSessionDownloadTaskCreationHook {
		let adapter = createFullyMockedAdapter()
		try? await adapter.downloadFile(with: downloadIdentifier, to: URL(fileURLWithPath: "/dev/null"))
		return try XCTUnwrap(downloadTaskManagerMock.lastOnURLSessionTaskCreation)
	}

	private func createUploadHook() async throws -> URLSessionUploadTaskCreationHook {
		let adapter = createFullyMockedAdapter()
		let taskRecord = UploadTaskRecord(correspondingItem: 3, lastFailedUploadDate: nil, uploadErrorCode: nil, uploadErrorDomain: nil, uploadStartedAt: Date())
		adapter.uploadFile(taskRecord: taskRecord, itemIdentifier: uploadIdentifier)
		await adapter.awaitWorkflows()
		return try XCTUnwrap(uploadTaskManagerMock.getTaskForOnURLSessionTaskCreationReceivedArguments?.onURLSessionTaskCreation)
	}

	private func assertHookReturnsOnlyAfterRegistrationCompletes<T: URLSessionTask>(_ hook: @escaping @concurrent @Sendable (T) async -> Void, task: T, identifier: NSFileProviderItemIdentifier) async throws {
		let registrationStarted = XCTestExpectation(description: "Registration started")
		let registrationCompletion = OneShotSignal<Void>()
		taskRegistratorMock.registerForItemWithIdentifierClosure = { _, _ in
			registrationStarted.fulfill()
			try await registrationCompletion.value
		}
		let hookReturnedEarly = XCTestExpectation(description: "Hook returned before registration completed")
		hookReturnedEarly.isInverted = true
		let hookReturned = XCTestExpectation(description: "Hook returned")
		Task {
			await hook(task)
			hookReturnedEarly.fulfill()
			hookReturned.fulfill()
		}

		await fulfillment(of: [registrationStarted], timeout: 5.0)
		await fulfillment(of: [hookReturnedEarly], timeout: 0.5)
		registrationCompletion.fulfill(())
		await fulfillment(of: [hookReturned], timeout: 5.0)

		XCTAssertIdentical(task, taskRegistratorMock.registerForItemWithIdentifierReceivedArguments?.task)
		XCTAssertEqual(identifier, taskRegistratorMock.registerForItemWithIdentifierReceivedArguments?.identifier)
		try await assertNeverResumed(task)
	}

	private func assertHookReturnsWhenRegistrationFails<T: URLSessionTask>(_ hook: @escaping @concurrent @Sendable (T) async -> Void, task: T) async throws {
		taskRegistratorMock.registerForItemWithIdentifierThrowableError = NSError(domain: "test", code: 1)

		await hook(task)

		try await assertNeverResumed(task)
	}

	/// Waits briefly, because resuming a task is not documented to change its state synchronously.
	private func assertNeverResumed(_ task: URLSessionTask, file: StaticString = #filePath, line: UInt = #line) async throws {
		try await Task.sleep(for: .milliseconds(100))
		XCTAssertEqual(.suspended, task.state, "the app must leave resuming the task to the provider", file: file, line: line)
	}

	private func unreachableURL() throws -> URL {
		return try XCTUnwrap(URL(string: "https://192.0.2.1/"))
	}
}
