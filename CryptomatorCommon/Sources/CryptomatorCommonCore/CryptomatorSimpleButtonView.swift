import SwiftUI

struct CryptomatorSimpleButtonView: View {
	let buttonTitle: String
	let onButtonTap: () -> Void
	let headerTitle: String

	var body: some View {
		List {
			Section {
				Button(buttonTitle) {
					onButtonTap()
				}
			} header: {
				HStack {
					Spacer()
					VStack(alignment: .center, spacing: 20) {
						Image("bot-vault")
						Text(headerTitle)
							.textCase(.none)
							.foregroundColor(.primary)
							.font(.body)
					}
					.padding(.bottom, 12)
					Spacer()
				}
			}
		}
		.setListBackgroundColor(.cryptomatorBackground)
	}
}

struct CryptomatorSimpleButtonView_Previews: PreviewProvider {
	static var previews: some View {
		CryptomatorSimpleButtonView(buttonTitle: "Button", onButtonTap: {}, headerTitle: "Header title.")
	}
}
