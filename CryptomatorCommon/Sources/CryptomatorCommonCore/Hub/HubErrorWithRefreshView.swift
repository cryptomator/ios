import SwiftUI

struct CryptomatorErrorWithRefreshView: View {
	var headerTitle: String
	var onRefresh: () -> Void

	var body: some View {
		CryptomatorSimpleButtonView(
			buttonTitle: LocalizedString.getValue("common.button.refresh"),
			onButtonTap: onRefresh,
			headerTitle: headerTitle
		)
	}
}

struct CryptomatorErrorWithRefreshView_Previews: PreviewProvider {
	static var previews: some View {
		CryptomatorErrorWithRefreshView(headerTitle: "Example Header Title", onRefresh: {})
	}
}
