import SwiftUI

struct HubDeviceRegistrationView: View {
	@Binding var deviceName: String
	@Binding var accountKey: String
	var onRegisterTap: () -> Void

	@FocusStateLegacy private var field: Field? = .deviceName

	private enum Field: CaseIterable {
		case deviceName
		case accountKey
	}

	var body: some View {
		List {
			Section {
				TextField(
					LocalizedString.getValue("hubAuthentication.deviceRegistration.deviceName.cells.name"),
					text: $deviceName,
					onCommit: { field = .accountKey }
				)
				.focusedLegacy($field, equals: .deviceName)
				.backportedSubmitlabel(.next)
			} footer: {
				Text(LocalizedString.getValue("hubAuthentication.deviceRegistration.deviceName.footer.title"))
			}

			Section {
				TextField(
					"Account Key",
					text: $accountKey,
					onCommit: onRegisterTap
				)
				.focusedLegacy($field, equals: .accountKey)
				.backportedSubmitlabel(.done)
			} footer: {
				Text(LocalizedString.getValue("hubAuthentication.deviceRegistration.accountKey.footer.title"))
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
		HubDeviceRegistrationView(deviceName: .constant(""), accountKey: .constant(""), onRegisterTap: {})
	}
}
