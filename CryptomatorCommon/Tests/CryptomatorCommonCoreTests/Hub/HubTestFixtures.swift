//
//  HubTestFixtures.swift
//  CryptomatorCommonCoreTests
//
//  Created by Tobias Hagemann on 03.09.26.
//  Copyright © 2026 Skymatic GmbH. All rights reserved.
//

import AppAuthCore
import Foundation
import JOSESwift

enum HubTestFixtures {
	/// Vault config for the hub vault `75af21b7-4849-4558-b05c-de6dc9077a67` at `https://testing.hub.cryptomator.org/hub30/`.
	static let vaultConfigToken = "eyJraWQiOiJodWIraHR0cHM6Ly90ZXN0aW5nLmh1Yi5jcnlwdG9tYXRvci5vcmcvaHViMzAvYXBpL3ZhdWx0cy83NWFmMjFiNy00ODQ5LTQ1NTgtYjA1Yy1kZTZkYzkwNzdhNjciLCJ0eXAiOiJqd3QiLCJhbGciOiJIUzI1NiIsImh1YiI6eyJjbGllbnRJZCI6ImNyeXB0b21hdG9yIiwiYXV0aEVuZHBvaW50IjoiaHR0cHM6Ly90ZXN0aW5nLmh1Yi5jcnlwdG9tYXRvci5vcmcva2MvcmVhbG1zL2h1YjMwL3Byb3RvY29sL29wZW5pZC1jb25uZWN0L2F1dGgiLCJ0b2tlbkVuZHBvaW50IjoiaHR0cHM6Ly90ZXN0aW5nLmh1Yi5jcnlwdG9tYXRvci5vcmcva2MvcmVhbG1zL2h1YjMwL3Byb3RvY29sL29wZW5pZC1jb25uZWN0L3Rva2VuIiwiYXV0aFN1Y2Nlc3NVcmwiOiJodHRwczovL3Rlc3RpbmcuaHViLmNyeXB0b21hdG9yLm9yZy9odWIzMC9hcHAvdW5sb2NrLXN1Y2Nlc3M_dmF1bHQ9NzVhZjIxYjctNDg0OS00NTU4LWIwNWMtZGU2ZGM5MDc3YTY3IiwiYXV0aEVycm9yVXJsIjoiaHR0cHM6Ly90ZXN0aW5nLmh1Yi5jcnlwdG9tYXRvci5vcmcvaHViMzAvYXBwL3VubG9jay1lcnJvcj92YXVsdD03NWFmMjFiNy00ODQ5LTQ1NTgtYjA1Yy1kZTZkYzkwNzdhNjciLCJhcGlCYXNlVXJsIjoiaHR0cHM6Ly90ZXN0aW5nLmh1Yi5jcnlwdG9tYXRvci5vcmcvaHViMzAvYXBpLyIsImRldmljZXNSZXNvdXJjZVVybCI6Imh0dHBzOi8vdGVzdGluZy5odWIuY3J5cHRvbWF0b3Iub3JnL2h1YjMwL2FwaS9kZXZpY2VzLyJ9fQ.eyJqdGkiOiI3NWFmMjFiNy00ODQ5LTQ1NTgtYjA1Yy1kZTZkYzkwNzdhNjciLCJmb3JtYXQiOjgsImNpcGhlckNvbWJvIjoiU0lWX0dDTSIsInNob3J0ZW5pbmdUaHJlc2hvbGQiOjIyMH0.Z0x_5D073zo3smZq5q5wgDRheewcapCrIqg_0iD5qwM"

	static let encryptedUserKey = "eyJhbGciOiJFQ0RILUVTIiwiZW5jIjoiQTI1NkdDTSIsImVwayI6eyJrZXlfb3BzIjpbXSwiZXh0Ijp0cnVlLCJrdHkiOiJFQyIsIngiOiJoeHpiSWh6SUJza3A5ZkZFUmJSQ2RfOU1fbWYxNElqaDZhcnNoVXNkcEEyWno5ejZZNUs4NHpZR2I4b2FHemNUIiwieSI6ImJrMGRaNWhpelZ0TF9hN2hNejBjTUduNjhIRjZFdWlyNHdlclNkTFV5QWd2NWUzVzNYSG5sdHJ2VlRyU3pzUWYiLCJjcnYiOiJQLTM4NCJ9LCJhcHUiOiIiLCJhcHYiOiIifQ..pu3Q1nR_yvgRAapG.4zW0xm0JPxbcvZ66R-Mn3k841lHelDQfaUvsZZAtWsL2w4FMi6H_uu6ArAWYLtNREa_zfcPuyuJsFferYPSNRUWt4OW6aWs-l_wfo7G1ceEVxztQXzQiwD30UTA8OOdPcUuFfEq2-d9217jezrcyO6m6FjyssEZIrnRArUPWKzGdghXccGkkf0LTZcGJoHeKal-RtyP8PfvEAWTjSOCpBlSdUJ-1JL3tyd97uVFNaVuH3i7vvcMoUP_bdr0XW3rvRgaeC6X4daPLUvR1hK5MsutQMtM2vpFghS_zZxIQRqz3B2ECxa9Bjxhmn8kLX5heZ8fq3lH-bmJp1DxzZ4V1RkWk.yVwXG9yARa5Ihq2koh2NbQ"

	static let encryptedVaultKey = "eyJhbGciOiJFQ0RILUVTIiwiZW5jIjoiQTI1NkdDTSIsImVwayI6eyJrdHkiOiJFQyIsImNydiI6IlAtMzg0Iiwia2V5X29wcyI6W10sImV4dCI6dHJ1ZSwieCI6ImNZdlVFZm9LYkJjenZySE5zQjUxOGpycUxPMGJDOW5lZjR4NzFFMUQ5dk95MXRqd1piZzV3cFI0OE5nU1RQdHgiLCJ5IjoiaWRJekhCWERzSzR2NTZEeU9yczJOcDZsSG1zb29fMXV0VTlzX3JNdVVkbkxuVXIzUXdLZkhYMWdaVXREM1RKayJ9LCJhcHUiOiIiLCJhcHYiOiIifQ..0VZqu5ei9U3blGtq.eDvhU6drw7mIwvXu6Q.f05QnhI7JWG3IYHvexwdFQ"

	/// Device key the `encryptedUserKey` fixture is encrypted for, PKCS#8 DER, base64-encoded.
	static let devicePrivateKey = "MIG2AgEAMBAGByqGSM49AgEGBSuBBAAiBIGeMIGbAgEBBDB2bmFCWy2p+EbAn8NWS5Om+GA7c5LHhRZb8g2pSMSf0fsd7k7dZDVrnyHFiLdd/YGhZANiAAR6bsjTEdXKWIuu1Bvj6Y8wySlIROy7YpmVZTY128ItovCD8pcR4PnFljvAIb2MshCdr1alX4g6cgDOqcTeREiObcSfucOU9Ry1pJ/GnX6KA0eSljrk6rxjSDos8aiZ6Mg="
}

extension JWE {
	static func encryptedUserKeyStub() throws -> JWE {
		try JWE(compactSerialization: HubTestFixtures.encryptedUserKey)
	}

	static func encryptedVaultKeyStub() throws -> JWE {
		try JWE(compactSerialization: HubTestFixtures.encryptedVaultKey)
	}
}

extension OIDAuthState {
	/// An auth state whose `performAction` yields a fresh access token without contacting a token endpoint.
	static var stub: OIDAuthState {
		let configuration = OIDServiceConfiguration(authorizationEndpoint: URL(string: "https://example.com/authorize")!,
		                                            tokenEndpoint: URL(string: "https://example.com/token")!)
		let redirectURL = URL(string: "https://example.com/callback")!
		let authorizationRequest = OIDAuthorizationRequest(configuration: configuration,
		                                                   clientId: "cryptomator",
		                                                   scopes: nil,
		                                                   redirectURL: redirectURL,
		                                                   responseType: "code",
		                                                   additionalParameters: nil)
		let authorizationResponse = OIDAuthorizationResponse(request: authorizationRequest, parameters: [:])
		let tokenRequest = OIDTokenRequest(configuration: configuration,
		                                   grantType: OIDGrantTypeAuthorizationCode,
		                                   authorizationCode: "code",
		                                   redirectURL: redirectURL,
		                                   clientID: "cryptomator",
		                                   clientSecret: nil,
		                                   scope: nil,
		                                   refreshToken: nil,
		                                   codeVerifier: nil,
		                                   additionalParameters: nil)
		let tokenResponse = OIDTokenResponse(request: tokenRequest, parameters: [
			"access_token": "access-token" as NSString,
			"token_type": "Bearer" as NSString,
			"expires_in": NSNumber(value: 3600)
		])
		return OIDAuthState(authorizationResponse: authorizationResponse, tokenResponse: tokenResponse)
	}
}
