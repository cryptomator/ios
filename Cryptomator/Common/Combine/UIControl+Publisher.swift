//
//  UIControl+Publisher.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 06.08.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Combine
import UIKit

/**
 A custom subscription to capture `UIControl` target events.

 Taken from: <https://www.avanderlee.com/swift/custom-combine-publisher/>
 */
final class UIControlSubscription<SubscriberType: Subscriber, Control: UIControl>: Subscription where SubscriberType.Input == Control {
	private var subscriber: SubscriberType?
	private let control: Control

	init(subscriber: SubscriberType, control: Control, event: UIControl.Event) {
		self.subscriber = subscriber
		self.control = control
		control.addTarget(self, action: #selector(eventHandler), for: event)
	}

	func request(_ demand: Subscribers.Demand) {
		// We do nothing here as we only want to send events when they occur.
		// See, for more info: https://developer.apple.com/documentation/combine/subscribers/demand
	}

	func cancel() {
		subscriber = nil
	}

	@objc private func eventHandler() {
		_ = subscriber?.receive(control)
	}
}

struct UIControlPublisher<Control: UIControl>: Publisher {
	typealias Output = Control
	typealias Failure = Never

	let control: Control
	let controlEvents: UIControl.Event

	init(control: Control, events: UIControl.Event) {
		self.control = control
		self.controlEvents = events
	}

	func receive<S>(subscriber: S) where S: Subscriber, S.Failure == UIControlPublisher.Failure, S.Input == UIControlPublisher.Output {
		let subscription = UIControlSubscription(subscriber: subscriber, control: control, event: controlEvents)
		subscriber.receive(subscription: subscription)
	}
}

protocol CombineCompatible {}
extension UIControl: CombineCompatible {}
extension CombineCompatible where Self: UIControl {
	func publisher(for events: UIControl.Event) -> UIControlPublisher<Self> {
		return UIControlPublisher(control: self, events: events)
	}
}
