import Introspect
import SwiftUI

public extension View {
	func setListBackgroundColor(_ color: Color) -> some View {
		modifier(ListBackgroundModifier(color: color))
	}
}

struct ListBackgroundModifier: ViewModifier {
	let color: Color

	public func body(content: Content) -> some View {
		if #available(iOS 16, *) {
			content
				.scrollContentBackground(.hidden)
				.background(color)
		} else {
			content
				.introspectTableView {
					$0.backgroundColor = UIColor(color)
				}
		}
	}
}
