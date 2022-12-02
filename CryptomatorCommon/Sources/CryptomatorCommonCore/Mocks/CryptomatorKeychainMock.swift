//
//  CryptomatorKeychainMock.swift
//
//
//  Created by Philipp Schmid on 29.06.22.
//
#if DEBUG
import Foundation

// swiftlint:disable all

final class CryptomatorKeychainMock: CryptomatorKeychainType {
	// MARK: - set

	var setValueThrowableError: Error?
	var setValueCallsCount = 0
	var setValueCalled: Bool {
		setValueCallsCount > 0
	}

	var setValueReceivedArguments: (key: String, value: Data)?
	var setValueReceivedInvocations: [(key: String, value: Data)] = []
	var setValueClosure: ((String, Data) throws -> Void)?

	func set(_ key: String, value: Data) throws {
		if let error = setValueThrowableError {
			throw error
		}
		setValueCallsCount += 1
		setValueReceivedArguments = (key: key, value: value)
		setValueReceivedInvocations.append((key: key, value: value))
		try setValueClosure?(key, value)
	}

	// MARK: - getAsData

	var getAsDataCallsCount = 0
	var getAsDataCalled: Bool {
		getAsDataCallsCount > 0
	}

	var getAsDataReceivedKey: String?
	var getAsDataReceivedInvocations: [String] = []
	var getAsDataReturnValue: Data?
	var getAsDataClosure: ((String) -> Data?)?

	func getAsData(_ key: String) -> Data? {
		getAsDataCallsCount += 1
		getAsDataReceivedKey = key
		getAsDataReceivedInvocations.append(key)
		return getAsDataClosure.map({ $0(key) }) ?? getAsDataReturnValue
	}

	// MARK: - delete

	var deleteThrowableError: Error?
	var deleteCallsCount = 0
	var deleteCalled: Bool {
		deleteCallsCount > 0
	}

	var deleteReceivedKey: String?
	var deleteReceivedInvocations: [String] = []
	var deleteClosure: ((String) throws -> Void)?

	func delete(_ key: String) throws {
		if let error = deleteThrowableError {
			throw error
		}
		deleteCallsCount += 1
		deleteReceivedKey = key
		deleteReceivedInvocations.append(key)
		try deleteClosure?(key)
	}

	// MARK: - queryWithDict

	var queryWithDictCallsCount = 0
	var queryWithDictCalled: Bool {
		queryWithDictCallsCount > 0
	}

	var queryWithDictReceivedQuery: [String: Any]?
	var queryWithDictReceivedInvocations: [[String: AnyObject]] = []
	var queryWithDictReturnValue: [String: Any]!
	var queryWithDictClosure: (([String: AnyObject]) -> [String: Any])?

	func queryWithDict(_ query: [String: AnyObject]) -> [String: Any] {
		queryWithDictCallsCount += 1
		queryWithDictReceivedQuery = query
		queryWithDictReceivedInvocations.append(query)
		return queryWithDictClosure.map({ $0(query) }) ?? queryWithDictReturnValue
	}
}
// swiftlint:enable all
#endif
