import SwiftUI

struct HubAccessNotGrantedView: View {
	var onRefresh: () -> Void

	var body: some View {
		CryptomatorSimpleButtonView(
			buttonTitle: "Refresh",
			onButtonTap: onRefresh,
			headerTitle: "Your device has not vet been authorized to access this vault. Ask the vault owner to authorize it."
		)
	}
}

struct HubDeviceRegisteredSuccessfullyView_Previews: PreviewProvider {
	static var previews: some View {
		HubAccessNotGrantedView(onRefresh: {})
	}
}
