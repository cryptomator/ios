//
//  DropboxError.swift
//  CloudAccessPrivate
//
//  Created by Philipp Schmid on 03.06.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import Foundation
public enum DropboxError: Error {
	case createFolderError
	case unexpectedError
	case unexpectedResult
	case unexpectedMetadataType
	case getMetadataError
	case deleteFileError
	case asyncPollError

	case internalServerError
	case badInputError
	case authError
	case accessError
	case rateLimitError
	case httpError
	case clientError

	case tooManyWriteOperations
	case uploadFileError
}
