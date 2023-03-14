//
//  AddHubVaultView.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 21.07.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import SwiftUI

public struct AddHubVaultView: View {
	@ObservedObject var viewModel: HubVaultViewModel
	public var body: some View {
		VStack {
			switch viewModel.state {
			case .detectedVault:
				Text("Detected Hub vault")
				Button("Login") {
					if let loginViewModel = viewModel as? HubVaultAdding {
						loginViewModel.login()
					}
				}
			case .needsDeviceRegistration:
				Text("This seems to be the first Hub access from this device. In order to identify it for access authorization, you need to name this device.")
				TextField("Device name", text: $viewModel.deviceName)
				Button("Register") {
					Task {
						await viewModel.register()
					}
				}
			case .deviceRegisteredSuccessfully:
				Text("To access the vault, your device needs to be authorized by the vault owner.")
				Button("Continue") {
					Task {
						await viewModel.continueToAccessCheck()
					}
				}
			case .accessNotGranted:
				Text("Your device has not vet been authorized to access this vault. Ask the vault owner to authorize it.")
				Button("Refresh") {
					Task {
						await viewModel.refresh()
					}
				}
			case .receivedExistingKey:
				Text("Received existing key")
			case let .loading(text):
				ProgressView()
				Text(text)
			}
		}
		.padding()
	}
}

public protocol HubVaultAdding {
	func login()
}
