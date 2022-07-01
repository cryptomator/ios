//
//  S3LoginView.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 28.06.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import Combine
import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import SwiftUI

struct S3LoginView: View {
	@FocusStateLegacy private var focusedField: S3LoginField? = .displayName
	@ObservedObject var viewModel: S3LoginViewModel
	var body: some View {
		Form {
			TextField("Display Name",
			          text: $viewModel.displayName)
				.focusedLegacy($focusedField, equals: .displayName)
				.disableAutocorrection(true)
				.autocapitalization(.none)

			TextField("Access Key",
			          text: $viewModel.accessKey)
				.focusedLegacy($focusedField, equals: .accessKey)
				.disableAutocorrection(true)
				.autocapitalization(.none)

			SecureField("Secret Key",
			            text: $viewModel.secretKey)
				.focusedLegacy($focusedField, equals: .secretKey)
				.disableAutocorrection(true)
				.autocapitalization(.none)

			TextField("Existing Bucket",
			          text: $viewModel.existingBucket)
				.focusedLegacy($focusedField, equals: .existingBucket)
				.disableAutocorrection(true)
				.autocapitalization(.none)

			TextField("Endpoint",
			          text: $viewModel.endpoint)
				.focusedLegacy($focusedField, equals: .endpoint)
				.disableAutocorrection(true)
				.autocapitalization(.none)
				.keyboardType(.URL)

			TextField("Region",
			          text: $viewModel.region,
			          onCommit: {
			          	viewModel.saveS3Credential()
			          })
			          .focusedLegacy($focusedField, equals: .region)
			          .disableAutocorrection(true)
			          .autocapitalization(.none)
		}
		.introspectTableView(customize: { tableView in
			tableView.backgroundColor = .cryptomatorBackground
		})
	}
}

struct S3LoginView_Previews: PreviewProvider {
	static var previews: some View {
		S3LoginView(viewModel: .init())
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
