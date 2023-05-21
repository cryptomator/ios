import SwiftUI

public struct HubAuthenticationView: View {
	@ObservedObject var viewModel: HubAuthenticationViewModel

	public init(viewModel: HubAuthenticationViewModel) {
		self.viewModel = viewModel
	}

	public var body: some View {
		ZStack {
			Color.cryptomatorBackground
				.ignoresSafeArea()
			VStack {
				switch viewModel.authenticationFlowState {
				case .deviceRegistration:
					HubDeviceRegistrationView(
						deviceName: $viewModel.deviceName,
						onRegisterTap: { Task { await viewModel.register() }}
					)
				case .accessNotGranted:
					HubAccessNotGrantedView(onRefresh: { Task { await viewModel.refresh() }})
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
			.navigationTitle("Hub Vault")
			.alert(
				isPresented: .init(
					get: { viewModel.authenticationFlowState == .deviceRegistration(.needsAuthorization) },
					set: { _ in Task { await viewModel.continueToAccessCheck() }}
				)
			) {
				Alert(
					title: Text("Information"),
					message: Text("To access the vault, your device needs to be authorized by the vault owner."),
					dismissButton: .default(Text("Continue"))
				)
			}
		}
	}
}
