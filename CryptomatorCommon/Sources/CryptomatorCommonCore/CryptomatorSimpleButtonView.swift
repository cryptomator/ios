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
				VStack(alignment: .center, spacing: 20) {
					Image("bot-vault")
					Text(headerTitle)
						.textCase(.none)
						.foregroundColor(.primary)
						.font(.body)
						.multilineTextAlignment(.center)
				}
				.frame(maxWidth: .infinity)
				.padding(.bottom, 20)
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
