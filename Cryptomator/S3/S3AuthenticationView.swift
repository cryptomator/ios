//
//  S3AuthenticationView.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 28.06.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import Combine
import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import SwiftUI

struct S3AuthenticationView: View {
	@FocusState private var focusedField: S3LoginField?
	@ObservedObject var viewModel: S3AuthenticationViewModel
	var body: some View {
		Form {
			TextField(LocalizedString.getValue("s3Authentication.displayName"),
			          text: $viewModel.displayName)
				.focused($focusedField, equals: .displayName)
				.disableAutocorrection(true)
				.autocapitalization(.none)

			TextField(LocalizedString.getValue("s3Authentication.accessKey"),
			          text: $viewModel.accessKey)
				.focused($focusedField, equals: .accessKey)
				.disableAutocorrection(true)
				.autocapitalization(.none)

			SecureField(LocalizedString.getValue("s3Authentication.secretKey"),
			            text: $viewModel.secretKey)
				.focused($focusedField, equals: .secretKey)
				.disableAutocorrection(true)
				.autocapitalization(.none)

			TextField(LocalizedString.getValue("s3Authentication.existingBucket"),
			          text: $viewModel.existingBucket)
				.focused($focusedField, equals: .existingBucket)
				.disableAutocorrection(true)
				.autocapitalization(.none)

			TextField(LocalizedString.getValue("s3Authentication.endpoint"),
			          text: $viewModel.endpoint)
				.focused($focusedField, equals: .endpoint)
				.disableAutocorrection(true)
				.autocapitalization(.none)
				.keyboardType(.URL)

			TextField(LocalizedString.getValue("s3Authentication.region"),
			          text: $viewModel.region,
			          onCommit: {
			          	viewModel.saveS3Credential()
			          })
			          .focused($focusedField, equals: .region)
			          .disableAutocorrection(true)
			          .autocapitalization(.none)
		}
		.setListBackgroundColor(.cryptomatorBackground)
		.onAppear { focusedField = .displayName }
		.onSubmit { focusedField = focusedField?.next() }
	}
}

struct S3LoginView_Previews: PreviewProvider {
	static var previews: some View {
		S3AuthenticationView(viewModel: .init(credentialManager: S3CredentialManager.demo))
	}
}

enum S3LoginField: CaseIterable, Hashable {
	case displayName
	case accessKey
	case secretKey
	case existingBucket
	case endpoint
	case region
}
