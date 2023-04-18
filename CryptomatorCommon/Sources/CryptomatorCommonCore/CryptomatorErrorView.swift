import SwiftUI

public struct CryptomatorErrorView: View {
	let text: String?

	public init(text: String? = nil) {
		self.text = text
	}

	public var body: some View {
		VStack(spacing: 20) {
			Image(systemName: "exclamationmark.triangle.fill")
				.font(.system(size: 120))
				.foregroundColor(Color(UIColor.cryptomatorYellow))
			if let text {
				Text(text)
			}
		}.padding(.vertical, 20)
	}
}

struct CryptomatorErrorView_Previews: PreviewProvider {
	static var previews: some View {
		CryptomatorErrorView()
	}
}
