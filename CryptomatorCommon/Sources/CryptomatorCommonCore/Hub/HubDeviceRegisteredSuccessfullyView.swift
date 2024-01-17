import SwiftUI

struct HubAccessNotGrantedView: View {
	var onRefresh: () -> Void

	var body: some View {
		CryptomatorSimpleButtonView(
			buttonTitle: LocalizedString.getValue("common.button.refresh"),
			onButtonTap: onRefresh,
			headerTitle: LocalizedString.getValue("hubAuthentication.accessNotGranted")
		)
	}
}

struct HubDeviceRegisteredSuccessfullyView_Previews: PreviewProvider {
	static var previews: some View {
		HubAccessNotGrantedView(onRefresh: {})
	}
}
