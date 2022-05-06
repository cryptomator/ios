//
//  FileProviderAdapterTestCase.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 04.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation
import Promises
import XCTest
@testable import CryptomatorCommonCore
@testable import CryptomatorFileProvider

class FileProviderAdapterTestCase: CloudTaskExecutorTestCase {
	var adapter: FileProviderAdapter!
	var localURLProviderMock: LocalURLProviderMock!
	var fullVersionCheckerMock: FullVersionCheckerMock!
	var fileProviderItemUpdateDelegateMock: FileProviderItemUpdateDelegateMock!

	override func setUpWithError() throws {
		try super.setUpWithError()
		localURLProviderMock = LocalURLProviderMock()
		localURLProviderMock.domainIdentifier = .test
		fileProviderItemUpdateDelegateMock = FileProviderItemUpdateDelegateMock()
		fullVersionCheckerMock = FullVersionCheckerMock()
		fullVersionCheckerMock.isFullVersion = true
		adapter = FileProviderAdapter(domainIdentifier: .test,
		                              uploadTaskManager: uploadTaskManagerMock,
		                              cachedFileManager: cachedFileManagerMock,
		                              itemMetadataManager: metadataManagerMock,
		                              reparentTaskManager: reparentTaskManagerMock,
		                              deletionTaskManager: deletionTaskManagerMock,
		                              itemEnumerationTaskManager: itemEnumerationTaskManagerMock,
		                              downloadTaskManager: downloadTaskManagerMock,
		                              scheduler: WorkflowScheduler(maxParallelUploads: 1, maxParallelDownloads: 1),
		                              provider: cloudProviderMock,
		                              notificator: fileProviderItemUpdateDelegateMock,
		                              localURLProvider: localURLProviderMock,
		                              fullVersionChecker: fullVersionCheckerMock)
		uploadTaskManagerMock.createNewTaskRecordForClosure = {
			return UploadTaskRecord(correspondingItem: $0.id!, lastFailedUploadDate: nil, uploadErrorCode: nil, uploadErrorDomain: nil)
		}
		uploadTaskManagerMock.getTaskForClosure = {
			let id = $0.correspondingItem
			let metadata = try XCTUnwrap(self.metadataManagerMock.cachedMetadata[id])
			return UploadTask(taskRecord: $0, itemMetadata: metadata)
		}
	}

	class WorkflowSchedulerMock: WorkflowScheduler {
		init() {
			super.init(maxParallelUploads: 1, maxParallelDownloads: 1)
		}

		override func schedule<T>(_ workflow: Workflow<T>) -> Promise<T> {
			return Promise(CloudTaskTestError.correctPassthrough)
		}
	}

	func createFullyMockedAdapter() -> FileProviderAdapter {
		return FileProviderAdapter(domainIdentifier: .test, uploadTaskManager: uploadTaskManagerMock, cachedFileManager: cachedFileManagerMock, itemMetadataManager: metadataManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, itemEnumerationTaskManager: itemEnumerationTaskManagerMock, downloadTaskManager: downloadTaskManagerMock, scheduler: WorkflowSchedulerMock(), provider: cloudProviderMock, localURLProvider: localURLProviderMock)
	}
}

extension UploadTaskRecord: Equatable {
	public static func == (lhs: UploadTaskRecord, rhs: UploadTaskRecord) -> Bool {
		lhs.correspondingItem == rhs.correspondingItem && lhs.lastFailedUploadDate == rhs.lastFailedUploadDate && lhs.uploadErrorCode == rhs.uploadErrorCode && lhs.uploadErrorDomain == rhs.uploadErrorDomain
	}
}

extension NSFileProviderDomainIdentifier {
	static let test = NSFileProviderDomainIdentifier("Test")
}
