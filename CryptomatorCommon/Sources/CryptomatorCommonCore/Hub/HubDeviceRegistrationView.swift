import SwiftUI

struct HubDeviceRegistrationView: View {
	@Binding var deviceName: String
	@Binding var accountKey: String
	var onRegisterTap: () -> Void

	@FocusState private var field: Field?

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
				.focused($field, equals: .deviceName)
				.submitLabel(.next)
			} footer: {
				Text(LocalizedString.getValue("hubAuthentication.deviceRegistration.deviceName.footer.title"))
			}

			Section {
				TextField(
					"Account Key",
					text: $accountKey,
					onCommit: onRegisterTap
				)
				.focused($field, equals: .accountKey)
				.submitLabel(.done)
			} footer: {
				Text(LocalizedString.getValue("hubAuthentication.deviceRegistration.accountKey.footer.title"))
			}
		}
		.setListBackgroundColor(.cryptomatorBackground)
		.onAppear { field = .deviceName }
		.onSubmit { field = field?.next() }
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
