import SwiftUI

public struct HubAuthenticationView: View {
	@ObservedObject var viewModel: HubAuthenticationViewModel

	public init(viewModel: HubAuthenticationViewModel) {
		self.viewModel = viewModel
	}

	public var body: some View {
		VStack {
			switch viewModel.authenticationFlowState {
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
			case .userLogin:
				HubLoginView(onLogin: { Task { await viewModel.login() }})
			case .licenseExceeded:
				CryptomatorErrorView(text: "Your Cryptomator Hub instance has an invalid license. Please inform a Hub administrator to upgrade or renew the license.")
			case let .error(info):
				CryptomatorErrorView(text: info)
			}
		}
		.padding()
	}
}
