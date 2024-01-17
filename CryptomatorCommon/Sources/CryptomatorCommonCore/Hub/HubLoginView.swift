import SwiftUI

struct HubLoginView: View {
	var onLogin: () -> Void

	var body: some View {
		CryptomatorSimpleButtonView(
			buttonTitle: "Login",
			onButtonTap: onLogin,
			headerTitle: "Login to unlock your vault"
		)
	}
}

struct HubLoginView_Previews: PreviewProvider {
	static var previews: some View {
		HubLoginView(onLogin: {})
	}
}
