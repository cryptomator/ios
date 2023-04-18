import SwiftUI

struct HubLoginView: View {
	var onLogin: () -> Void

	var body: some View {
		Text("Login to unlock your vault")
		Button("Login") {
			onLogin()
		}
	}
}

struct HubLoginView_Previews: PreviewProvider {
	static var previews: some View {
		HubLoginView(onLogin: {})
	}
}
