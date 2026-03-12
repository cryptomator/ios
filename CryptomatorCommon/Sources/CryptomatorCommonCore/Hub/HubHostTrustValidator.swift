//
//  HubHostTrustValidator.swift
//  CryptomatorCommonCore
//
//  Created by Tobias Hagemann on 12.03.26.
//  Copyright © 2026 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation

public enum HubHostTrustError: Error, LocalizedError {
	case inconsistentHubAuthority
	case inconsistentAuthAuthority
	case httpNotAllowed(String)
	case invalidURL(String)

	public var errorDescription: String? {
		switch self {
		case .inconsistentHubAuthority, .inconsistentAuthAuthority, .invalidURL:
			return LocalizedString.getValue("hubAuthentication.trustHost.error.inconsistentAuthority")
		case let .httpNotAllowed(url):
			return String(format: LocalizedString.getValue("hubAuthentication.trustHost.error.httpNotAllowed"), url)
		}
	}
}

public enum HubHostTrustResult {
	case trusted
	case userConfirmationRequired(untrustedAuthorities: Set<String>)
}

public enum HubHostTrustValidator {
	public static func validate(hubConfig: HubConfig, vaultBaseURL: URL, trustedAuthorities: Set<String>) throws -> HubHostTrustResult {
		let hubURLs = [hubConfig.getAPIBaseURL(), vaultBaseURL].compactMap { $0 }
		let authURLs = [URL(string: hubConfig.authEndpoint), URL(string: hubConfig.tokenEndpoint)].compactMap { $0 }

		try checkConsistency(hubURLs, error: .inconsistentHubAuthority)
		try checkConsistency(authURLs, error: .inconsistentAuthAuthority)

		let allURLs = hubURLs + authURLs
		try checkHTTP(allURLs)

		var untrusted = Set<String>()
		for url in allURLs {
			guard let auth = authority(from: url) else {
				throw HubHostTrustError.invalidURL(url.absoluteString)
			}
			if isAutoTrusted(auth) || trustedAuthorities.contains(auth) {
				continue
			}
			untrusted.insert(auth)
		}

		if untrusted.isEmpty {
			return .trusted
		}
		return .userConfirmationRequired(untrustedAuthorities: untrusted)
	}

	public static func authority(from url: URL) -> String? {
		guard let scheme = url.scheme?.lowercased(), let host = url.host?.lowercased() else {
			return nil
		}
		let port = url.port
		let isDefaultPort = (scheme == "https" && port == 443) || (scheme == "http" && port == 80)
		if let port, !isDefaultPort {
			return "\(scheme)://\(host):\(port)"
		}
		return "\(scheme)://\(host)"
	}

	// MARK: - Internal

	private static func checkConsistency(_ urls: [URL], error: HubHostTrustError) throws {
		let authorities = Set(urls.compactMap { authority(from: $0) })
		if authorities.count > 1 {
			throw error
		}
	}

	private static func checkHTTP(_ urls: [URL]) throws {
		for url in urls {
			guard url.scheme?.lowercased() == "http" else { continue }
			if isLocalhost(url) { continue }
			throw HubHostTrustError.httpNotAllowed(url.absoluteString)
		}
	}

	private static func isLocalhost(_ url: URL) -> Bool {
		guard let host = url.host?.lowercased() else { return false }
		return host == "localhost" || host == "127.0.0.1" || host == "::1"
	}

	private static func isAutoTrusted(_ authority: String) -> Bool {
		guard let components = URLComponents(string: authority), let host = components.host?.lowercased() else {
			return false
		}
		return host == "cryptomator.cloud" || host.hasSuffix(".cryptomator.cloud")
	}
}
