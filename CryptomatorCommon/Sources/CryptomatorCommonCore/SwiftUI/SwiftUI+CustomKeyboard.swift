//
//  SwiftUI+CustomKeyboard.swift
//
//
//  Created by Philipp Schmid on 23.12.23.
//

import SwiftUI
import SwiftUIIntrospect

public extension View {
	func backportedSubmitlabel(_ submitLabel: BackportedSubmitLabel) -> some View {
		modifier(BackportedSubmitLabelModifier(label: submitLabel))
	}
}

public enum BackportedSubmitLabel {
	/// Defines a submit label with text of "Done".
	case done

	/// Defines a submit label with text of "Go".
	case go

	/// Defines a submit label with text of "Send".
	case send

	/// Defines a submit label with text of "Join".
	case join

	/// Defines a submit label with text of "Route".
	case route

	/// Defines a submit label with text of "Search".
	case search

	/// Defines a submit label with text of "Return".
	case `return`

	/// Defines a submit label with text of "Next".
	case next

	/// Defines a submit label with text of "Continue".
	case `continue`

	@available(iOS 15, *)
	var submitLabel: SubmitLabel {
		switch self {
		case .done:
			return .done
		case .go:
			return .go
		case .send:
			return .send
		case .join:
			return .join
		case .route:
			return .route
		case .search:
			return .search
		case .return:
			return .return
		case .next:
			return .next
		case .continue:
			return .continue
		}
	}

	var returnKeyType: UIReturnKeyType {
		switch self {
		case .done:
			return .done
		case .go:
			return .go
		case .send:
			return .send
		case .join:
			return .join
		case .route:
			return .route
		case .search:
			return .search
		case .return:
			return .default
		case .next:
			return .next
		case .continue:
			return .continue
		}
	}
}

struct BackportedSubmitLabelModifier: ViewModifier {
	let label: BackportedSubmitLabel

	public func body(content: Content) -> some View {
		if #available(iOS 15, *) {
			content
				.submitLabel(label.submitLabel)
		} else {
			content
				.introspect(.textField, on: .iOS(.v13, .v14), scope: .ancestor) { textField in
					textField.returnKeyType = label.returnKeyType
				}
		}
	}
}
