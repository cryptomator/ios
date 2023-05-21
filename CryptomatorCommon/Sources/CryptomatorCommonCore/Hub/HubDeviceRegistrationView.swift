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
					"",
					text: $deviceName,
					onCommit: onRegisterTap
				)
				.focusedLegacy($field, equals: .deviceName)
			} footer: {
				Text("This seems to be the first Hub access from this device. In order to identify it for access authorization, you need to name this device.")
			}
		}
		.setListBackgroundColor(.cryptomatorBackground)
		.toolbar {
			ToolbarItem(placement: .primaryAction) {
				Button("Register") {
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
