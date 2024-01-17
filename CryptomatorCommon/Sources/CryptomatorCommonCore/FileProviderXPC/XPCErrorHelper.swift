//
//  XPCErrorHelper.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 07.02.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import Foundation

public enum XPCErrorHelper {
	/**
	 Bridges a Swift Error to an XPC compatible NSError.

	 Since the lazy evaluation of the userInfo does not work for XPC, in order to not lose the `localizedDescription`, it is evaluated eagerly.
	 */
	public static func bridgeError(_ error: Error) -> NSError {
		let nsError = error as NSError
		var userInfo = nsError.userInfo
		userInfo[NSLocalizedDescriptionKey] = error.localizedDescription
		return NSError(domain: nsError.domain, code: nsError.code, userInfo: userInfo)
	}
}
