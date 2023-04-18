import SwiftUI

public struct CryptomatorSuccessView: View {
	let text: String
	let buttonText: String
	let onButtonTap: () -> Void
	let buttonColor: Color
	let backgroundColor: Color

	public init(text: String, buttonText: String, onButtonTap: @escaping () -> Void, buttonColor: Color, backgroundColor: Color) {
		self.text = text
		self.buttonText = buttonText
		self.onButtonTap = onButtonTap
		self.buttonColor = buttonColor
		self.backgroundColor = backgroundColor
	}

	public var body: some View {
		ZStack {
			backgroundColor
			VStack(spacing: 32) {
				Spacer()
				Image("bot-vault")
				Text(text)
				Spacer()
				Button {
					onButtonTap()
				} label: {
					Text(buttonText)
						.foregroundColor(.white)
						.bold()
						.padding()
						.frame(maxWidth: .infinity)
						.background(buttonColor)
						.cornerRadius(8)
						.padding(.horizontal)
				}
			}
		}
	}
}

struct CryptomatorSuccessView_Previews: PreviewProvider {
	static var previews: some View {
		CryptomatorSuccessView(text: "Lorem \nipsum", buttonText: "Continue", onButtonTap: {}, buttonColor: .blue, backgroundColor: .clear)
	}
}
