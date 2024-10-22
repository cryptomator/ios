//
//  FileProviderCoordinatorError.swift
//  Cryptomator
//
//  Created by Majid Achhoud on 11.10.24.
//  Copyright © 2024 Skymatic GmbH. All rights reserved.
//

import Foundation

public enum FileProviderCoordinatorError: Error {
	case unauthorized(vaultName: String)
}
