import SwiftUI

struct HubDeviceRegistrationView: View {
	@Binding var deviceName: String
	var onRegisterTap: () -> Void

	@FocusStateLegacy private var field: Field? = .deviceName

	private enum Field: CaseIterable {
		case deviceName
	}

	var body: some View {
		List {
			Section {
				TextField(
					LocalizedString.getValue("hubAuthentication.deviceRegistration.deviceName.cells.name"),
					text: $deviceName,
					onCommit: onRegisterTap
				)
				.focusedLegacy($field, equals: .deviceName)
			} footer: {
				Text(LocalizedString.getValue("hubAuthentication.deviceRegistration.deviceName.footer.title"))
			}
		}
		.setListBackgroundColor(.cryptomatorBackground)
		.toolbar {
			ToolbarItem(placement: .primaryAction) {
				Button(LocalizedString.getValue("common.button.register")) {
					onRegisterTap()
				}
			}
		}
	}
}

struct HubDeviceRegistrationView_Previews: PreviewProvider {
	static var previews: some View {
		HubDeviceRegistrationView(deviceName: .constant(""), onRegisterTap: {})
	}
}
