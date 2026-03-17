import SwiftUI

public extension View {
	func setListBackgroundColor(_ color: Color) -> some View {
		modifier(ListBackgroundModifier(color: color))
	}
}

struct ListBackgroundModifier: ViewModifier {
	let color: Color

	func body(content: Content) -> some View {
		content
			.scrollContentBackground(.hidden)
			.background(color)
	}
}
