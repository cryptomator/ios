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
			VStack(spacing: 20) {
				switch viewModel.authenticationFlowState {
				case .deviceRegistration:
					HubDeviceRegistrationView(
						deviceName: $viewModel.deviceName,
						accountKey: $viewModel.setupCode,
						onRegisterTap: { Task { await viewModel.register() }}
					)
				case .accessNotGranted:
					HubAccessNotGrantedView(onRefresh: { Task { await viewModel.refresh() }})
				case .licenseExceeded:
					CryptomatorErrorView(text: LocalizedString.getValue("hubAuthentication.licenseExceeded"))
				case let .error(description):
					CryptomatorErrorView(text: description)
				case .none:
					EmptyView()
				}
			}
			.padding()
			.navigationTitle(LocalizedString.getValue("hubAuthentication.title"))
			.alert(
				isPresented: .init(
					get: { viewModel.authenticationFlowState == .deviceRegistration(.needsAuthorization) },
					set: { _ in Task { await viewModel.continueToAccessCheck() }}
				)
			) {
				Alert(
					title: Text(LocalizedString.getValue("hubAuthentication.deviceRegistration.needsAuthorization.alert.title")),
					message: Text(LocalizedString.getValue("hubAuthentication.deviceRegistration.needsAuthorization.alert.message")),
					dismissButton: .default(Text(LocalizedString.getValue("common.button.ok")))
				)
			}
		}
	}
}
