//
//  ReturnButtonSupport.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 17.11.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Combine
import Foundation

protocol ReturnButtonSupport {
	var lastReturnButtonPressed: AnyPublisher<Void, Never> { get }
}

extension ReturnButtonSupport where Self: AnyObject {
	func setupReturnButtonSupport(for cellViewModels: [TextFieldCellViewModel], subscribers: inout Set<AnyCancellable>) -> AnyPublisher<Void, Never> {
		let publisher = PassthroughSubject<Void, Never>()
		for (i, viewModel) in cellViewModels.dropLast().enumerated() {
			viewModel.startListeningToReturnButtonPressedEvents().sink {
				cellViewModels[i + 1].becomeFirstResponder()
			}.store(in: &subscribers)
		}
		cellViewModels.last?.startListeningToReturnButtonPressedEvents().sink {
			publisher.send()
		}.store(in: &subscribers)
		return publisher.eraseToAnyPublisher()
	}
}
