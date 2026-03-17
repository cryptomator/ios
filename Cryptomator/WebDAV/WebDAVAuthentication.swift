//
//  WebDAVAuthentication.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 22.08.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import SwiftUI

struct WebDAVAuthentication: View {
	enum Fields: CaseIterable {
		case url
		case username
		case password
	}

	@ObservedObject var viewModel: WebDAVAuthenticationViewModel
	@FocusState private var focusedField: Fields?

	var body: some View {
		Form {
			TextField(LocalizedString.getValue("common.cells.url"), text: $viewModel.url)
				.keyboardType(.URL)
				.disableAutocorrection(true)
				.textContentType(.URL)
				.focused($focusedField, equals: .url)

			TextField(LocalizedString.getValue("common.cells.username"), text: $viewModel.username)
				.keyboardType(.asciiCapable)
				.autocapitalization(.none)
				.disableAutocorrection(true)
				.textContentType(.username)
				.focused($focusedField, equals: .username)

			SecureField(LocalizedString.getValue("common.cells.password"), text: $viewModel.password) {
				viewModel.saveAccount()
			}
			.focused($focusedField, equals: .password)
		}
		.setListBackgroundColor(.cryptomatorBackground)
		.onAppear { focusedField = .url }
		.onSubmit { focusedField = focusedField?.next() }
	}
}

struct WebDAVAuthentication_Previews: PreviewProvider {
	static var previews: some View {
		WebDAVAuthentication(viewModel: WebDAVAuthenticationViewModel())
	}
}
