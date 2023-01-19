//
//  UploadTaskManagerMock.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 16.03.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import Foundation
@testable import CryptomatorFileProvider

// swiftlint:disable all
final class UploadTaskManagerMock: UploadTaskManager {
	// MARK: - createNewTaskRecord

	var createNewTaskRecordForThrowableError: Error?
	var createNewTaskRecordForCallsCount = 0
	var createNewTaskRecordForCalled: Bool {
		createNewTaskRecordForCallsCount > 0
	}

	var createNewTaskRecordForReceivedItemMetadata: ItemMetadata?
	var createNewTaskRecordForReceivedInvocations: [ItemMetadata] = []
	var createNewTaskRecordForReturnValue: UploadTaskRecord!
	var createNewTaskRecordForClosure: ((ItemMetadata) throws -> UploadTaskRecord)?

	func createNewTaskRecord(for itemMetadata: ItemMetadata) throws -> UploadTaskRecord {
		if let error = createNewTaskRecordForThrowableError {
			throw error
		}
		createNewTaskRecordForCallsCount += 1
		createNewTaskRecordForReceivedItemMetadata = itemMetadata
		createNewTaskRecordForReceivedInvocations.append(itemMetadata)
		return try createNewTaskRecordForClosure.map({ try $0(itemMetadata) }) ?? createNewTaskRecordForReturnValue
	}

	// MARK: - getTaskRecord

	var getTaskRecordForThrowableError: Error?
	var getTaskRecordForCallsCount = 0
	var getTaskRecordForCalled: Bool {
		getTaskRecordForCallsCount > 0
	}

	var getTaskRecordForReceivedId: Int64?
	var getTaskRecordForReceivedInvocations: [Int64] = []
	var getTaskRecordForReturnValue: UploadTaskRecord?
	var getTaskRecordForClosure: ((Int64) throws -> UploadTaskRecord?)?

	func getTaskRecord(for id: Int64) throws -> UploadTaskRecord? {
		if let error = getTaskRecordForThrowableError {
			throw error
		}
		getTaskRecordForCallsCount += 1
		getTaskRecordForReceivedId = id
		getTaskRecordForReceivedInvocations.append(id)
		return try getTaskRecordForClosure.map({ try $0(id) }) ?? getTaskRecordForReturnValue
	}

	// MARK: - updateTaskRecord

	var updateTaskRecordWithLastFailedUploadDateUploadErrorCodeUploadErrorDomainThrowableError: Error?
	var updateTaskRecordWithLastFailedUploadDateUploadErrorCodeUploadErrorDomainCallsCount = 0
	var updateTaskRecordWithLastFailedUploadDateUploadErrorCodeUploadErrorDomainCalled: Bool {
		updateTaskRecordWithLastFailedUploadDateUploadErrorCodeUploadErrorDomainCallsCount > 0
	}

	var updateTaskRecordWithLastFailedUploadDateUploadErrorCodeUploadErrorDomainReceivedArguments: (id: Int64, lastFailedUploadDate: Date, uploadErrorCode: Int, uploadErrorDomain: String)?
	var updateTaskRecordWithLastFailedUploadDateUploadErrorCodeUploadErrorDomainReceivedInvocations: [(id: Int64, lastFailedUploadDate: Date, uploadErrorCode: Int, uploadErrorDomain: String)] = []
	var updateTaskRecordWithLastFailedUploadDateUploadErrorCodeUploadErrorDomainClosure: ((Int64, Date, Int, String) throws -> Void)?

	func updateTaskRecord(with id: Int64, lastFailedUploadDate: Date, uploadErrorCode: Int, uploadErrorDomain: String) throws {
		if let error = updateTaskRecordWithLastFailedUploadDateUploadErrorCodeUploadErrorDomainThrowableError {
			throw error
		}
		updateTaskRecordWithLastFailedUploadDateUploadErrorCodeUploadErrorDomainCallsCount += 1
		updateTaskRecordWithLastFailedUploadDateUploadErrorCodeUploadErrorDomainReceivedArguments = (id: id, lastFailedUploadDate: lastFailedUploadDate, uploadErrorCode: uploadErrorCode, uploadErrorDomain: uploadErrorDomain)
		updateTaskRecordWithLastFailedUploadDateUploadErrorCodeUploadErrorDomainReceivedInvocations.append((id: id, lastFailedUploadDate: lastFailedUploadDate, uploadErrorCode: uploadErrorCode, uploadErrorDomain: uploadErrorDomain))
		try updateTaskRecordWithLastFailedUploadDateUploadErrorCodeUploadErrorDomainClosure?(id, lastFailedUploadDate, uploadErrorCode, uploadErrorDomain)
	}

	// MARK: - updateTaskRecord

	var updateTaskRecordErrorThrowableError: Error?
	var updateTaskRecordErrorCallsCount = 0
	var updateTaskRecordErrorCalled: Bool {
		updateTaskRecordErrorCallsCount > 0
	}

	var updateTaskRecordErrorReceivedArguments: (task: UploadTaskRecord, error: NSError)?
	var updateTaskRecordErrorReceivedInvocations: [(task: UploadTaskRecord, error: NSError)] = []
	var updateTaskRecordErrorClosure: ((inout UploadTaskRecord, NSError) throws -> Void)?

	func updateTaskRecord(_ task: inout UploadTaskRecord, error: NSError) throws {
		if let error = updateTaskRecordErrorThrowableError {
			throw error
		}
		updateTaskRecordErrorCallsCount += 1
		updateTaskRecordErrorReceivedArguments = (task: task, error: error)
		updateTaskRecordErrorReceivedInvocations.append((task: task, error: error))
		try updateTaskRecordErrorClosure?(&task, error)
	}

	// MARK: - getCorrespondingTaskRecords

	var getCorrespondingTaskRecordsIdsThrowableError: Error?
	var getCorrespondingTaskRecordsIdsCallsCount = 0
	var getCorrespondingTaskRecordsIdsCalled: Bool {
		getCorrespondingTaskRecordsIdsCallsCount > 0
	}

	var getCorrespondingTaskRecordsIdsReceivedIds: [Int64]?
	var getCorrespondingTaskRecordsIdsReceivedInvocations: [[Int64]] = []
	var getCorrespondingTaskRecordsIdsReturnValue: [UploadTaskRecord?]!
	var getCorrespondingTaskRecordsIdsClosure: (([Int64]) throws -> [UploadTaskRecord?])?

	func getCorrespondingTaskRecords(ids: [Int64]) throws -> [UploadTaskRecord?] {
		if let error = getCorrespondingTaskRecordsIdsThrowableError {
			throw error
		}
		getCorrespondingTaskRecordsIdsCallsCount += 1
		getCorrespondingTaskRecordsIdsReceivedIds = ids
		getCorrespondingTaskRecordsIdsReceivedInvocations.append(ids)
		return try getCorrespondingTaskRecordsIdsClosure.map({ try $0(ids) }) ?? getCorrespondingTaskRecordsIdsReturnValue
	}

	// MARK: - removeTaskRecord

	var removeTaskRecordForThrowableError: Error?
	var removeTaskRecordForCallsCount = 0
	var removeTaskRecordForCalled: Bool {
		removeTaskRecordForCallsCount > 0
	}

	var removeTaskRecordForReceivedId: Int64?
	var removeTaskRecordForReceivedInvocations: [Int64] = []
	var removeTaskRecordForClosure: ((Int64) throws -> Void)?

	func removeTaskRecord(for id: Int64) throws {
		if let error = removeTaskRecordForThrowableError {
			throw error
		}
		removeTaskRecordForCallsCount += 1
		removeTaskRecordForReceivedId = id
		removeTaskRecordForReceivedInvocations.append(id)
		try removeTaskRecordForClosure?(id)
	}

	// MARK: - getTask

	var getTaskForOnURLSessionTaskCreationThrowableError: Error?
	var getTaskForOnURLSessionTaskCreationCallsCount = 0
	var getTaskForOnURLSessionTaskCreationCalled: Bool {
		getTaskForOnURLSessionTaskCreationCallsCount > 0
	}

	var getTaskForOnURLSessionTaskCreationReceivedArguments: (uploadTask: UploadTaskRecord, onURLSessionTaskCreation: URLSessionTaskCreationClosure?)?
	var getTaskForOnURLSessionTaskCreationReceivedInvocations: [(uploadTask: UploadTaskRecord, onURLSessionTaskCreation: URLSessionTaskCreationClosure?)] = []
	var getTaskForOnURLSessionTaskCreationReturnValue: UploadTask!
	var getTaskForOnURLSessionTaskCreationClosure: ((UploadTaskRecord, URLSessionTaskCreationClosure?) throws -> UploadTask)?

	func getTask(for uploadTask: UploadTaskRecord, onURLSessionTaskCreation: URLSessionTaskCreationClosure?) throws -> UploadTask {
		if let error = getTaskForOnURLSessionTaskCreationThrowableError {
			throw error
		}
		getTaskForOnURLSessionTaskCreationCallsCount += 1
		getTaskForOnURLSessionTaskCreationReceivedArguments = (uploadTask: uploadTask, onURLSessionTaskCreation: onURLSessionTaskCreation)
		getTaskForOnURLSessionTaskCreationReceivedInvocations.append((uploadTask: uploadTask, onURLSessionTaskCreation: onURLSessionTaskCreation))
		return try getTaskForOnURLSessionTaskCreationClosure.map({ try $0(uploadTask, onURLSessionTaskCreation) }) ?? getTaskForOnURLSessionTaskCreationReturnValue
	}
}

// swiftlint:enable all
