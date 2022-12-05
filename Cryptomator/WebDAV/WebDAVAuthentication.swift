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
	@FocusStateLegacy private var focusedField: Fields? = .url

	var body: some View {
		Form {
			TextField(LocalizedString.getValue("common.cells.url"), text: $viewModel.url)
				.keyboardType(.URL)
				.disableAutocorrection(true)
				.textContentType(.URL)
				.focusedLegacy($focusedField, equals: .url)

			TextField(LocalizedString.getValue("common.cells.username"), text: $viewModel.username)
				.keyboardType(.asciiCapable)
				.autocapitalization(.none)
				.disableAutocorrection(true)
				.textContentType(.username)
				.focusedLegacy($focusedField, equals: .username)

			SecureField(LocalizedString.getValue("common.cells.password"), text: $viewModel.password) {
				viewModel.saveAccount()
			}
			.focusedLegacy($focusedField, equals: .password)
		}
		.introspectTableView(customize: { tableView in
			tableView.backgroundColor = .cryptomatorBackground
		})
		.alert(isPresented: $viewModel.showUntrustedCertificateError) {
			untrustedCertificateAlert
		}
		.alert(isPresented: $viewModel.showAllowInsecureConnectionAlert) {
			insecureConnectionAlert
		}
	}

	private var untrustedCertificateAlert: Alert {
		Alert(title: Text(LocalizedString.getValue("untrustedTLSCertificate.title")),
		      message: Text(LocalizedString.getValue("untrustedTLSCertificate.message")),
		      primaryButton: .default(Text(LocalizedString.getValue("untrustedTLSCertificate.add")),
		                              action: {
		                              	viewModel.allowCertificate()
		                              }),
		      secondaryButton: .cancel(Text(LocalizedString.getValue("untrustedTLSCertificate.dismiss"))))
	}

	private var insecureConnectionAlert: Alert {
		Alert(title: Text(LocalizedString.getValue("webDAVAuthentication.httpConnection.alert.title")),
		      message: Text(LocalizedString.getValue("webDAVAuthentication.httpConnection.alert.message")),
		      primaryButton: .default(Text(LocalizedString.getValue("webDAVAuthentication.httpConnection.change")),
		                              action: {
		                              	viewModel.saveAccountWithTransformedURL()
		                              }),
		      secondaryButton: .destructive(Text(LocalizedString.getValue("webDAVAuthentication.httpConnection.continue")),
		                                    action: {
		                                    	viewModel.saveAccountWithInsecureConnection()
		                                    }))
	}
}

struct WebDAVAuthentication_Previews: PreviewProvider {
	static var previews: some View {
		WebDAVAuthentication(viewModel: WebDAVAuthenticationViewModel())
	}
}
