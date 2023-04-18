import CryptomatorCommonCore
import Foundation
import SwiftUI

struct DetectedHubVaultViewModel {
	let backgroundColor = Color(UIColor.cryptomatorBackground)
	let buttonColor = Color(UIColor.cryptomatorPrimary)
	let description: String = "Detected Hub vault\nDo you want to login?"
	let buttonText: String = "Login"
	let onButtonTap: () -> Void
}

extension CryptomatorSuccessView {
	init(viewModel: DetectedHubVaultViewModel) {
		self.init(text: viewModel.description,
		          buttonText: viewModel.buttonText,
		          onButtonTap: viewModel.onButtonTap,
		          buttonColor: viewModel.buttonColor,
		          backgroundColor: viewModel.backgroundColor)
	}
}
