//
//  SwiftUI+Focus.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 28.06.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import Foundation
import Introspect
import SwiftUI

// inspired by https://github.com/art-technologies/swift-focuser

public extension View {
	func focusedLegacy<T: CaseIterable & Hashable>(_ focusedField: Binding<T?>, equals: T) -> some View {
		modifier(FocusModifier(focusedField: focusedField, equals: equals))
	}
}

class TextFieldDelegate: NSObject, UITextFieldDelegate {
	var onReturnTap: (() -> Void)?
	var onFocus: (() -> Void)?
	weak var forwardToDelegate: UITextFieldDelegate?

	func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
		forwardToDelegate?.textFieldShouldBeginEditing?(textField) ?? true
	}

	func textFieldDidBeginEditing(_ textField: UITextField) {
		onFocus?()
		forwardToDelegate?.textFieldDidBeginEditing?(textField)
	}

	func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
		forwardToDelegate?.textFieldShouldEndEditing?(textField) ?? true
	}

	func textFieldDidEndEditing(_ textField: UITextField) {
		forwardToDelegate?.textFieldDidEndEditing?(textField)
	}

	func textFieldDidEndEditing(_ textField: UITextField, reason: UITextField.DidEndEditingReason) {
		forwardToDelegate?.textFieldDidEndEditing?(textField)
	}

	func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
		forwardToDelegate?.textField?(textField, shouldChangeCharactersIn: range, replacementString: string) ?? true
	}

	func textFieldDidChangeSelection(_ textField: UITextField) {
		forwardToDelegate?.textFieldDidChangeSelection?(textField)
	}

	func textFieldShouldClear(_ textField: UITextField) -> Bool {
		forwardToDelegate?.textFieldShouldClear?(textField) ?? true
	}

	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		onReturnTap?()
		return forwardToDelegate?.textFieldShouldReturn?(textField) ?? true
	}
}

struct FocusModifier<T: CaseIterable & Hashable>: ViewModifier {
	@Binding var focusedField: T?
	var equals: T
	// swiftlint:disable:next weak_delegate
	@State var delegate = TextFieldDelegate()

	public func body(content: Content) -> some View {
		content
			.introspectTextField { textField in
				if !(textField.delegate is TextFieldDelegate) {
					delegate.forwardToDelegate = textField.delegate
					textField.delegate = delegate
				}

				delegate.onReturnTap = {
					focusedField = focusedField?.next()
				}
				delegate.onFocus = {
					focusedField = equals
				}

				if focusedField == equals {
					textField.becomeFirstResponder()
				}
			}
	}
}

extension CaseIterable where Self: Equatable {
	func next() -> Self? {
		let all = Self.allCases
		let idx = all.firstIndex(of: self)!
		let next = all.index(after: idx)
		guard next < all.endIndex else {
			return nil
		}
		return all[next]
	}
}

@propertyWrapper public struct FocusStateLegacy<Value>: DynamicProperty where Value: Hashable {
	@State var form: Value?

	public var projectedValue: Binding<Value?> {
		Binding(
			get: { wrappedValue },
			set: { wrappedValue = $0 }
		)
	}

	public var wrappedValue: Value? {
		get {
			return form
		}

		nonmutating set {
			form = newValue
		}
	}

	public init(wrappedValue: Value?) {
		self._form = State(initialValue: wrappedValue)
	}
}
