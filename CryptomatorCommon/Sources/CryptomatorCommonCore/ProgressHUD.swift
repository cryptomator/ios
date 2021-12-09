//
//  ProgressHUD.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 02.11.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Promises
import UIKit

public class ProgressHUD {
	public var minimumDisplayTime: TimeInterval
	public var text: String? {
		get {
			return hud.text
		}
		set {
			hud.text = newValue
		}
	}

	private lazy var hud: HUDController = {
		let hud = HUDController()
		hud.modalPresentationStyle = .overFullScreen
		hud.modalTransitionStyle = .crossDissolve
		return hud
	}()

	private var displayTimestamp: CFAbsoluteTime = 0.0

	public init(minimumDisplayTime: TimeInterval = 1.0) {
		self.minimumDisplayTime = minimumDisplayTime
	}

	public func show(presentingViewController: UIViewController, animated: Bool = true) {
		displayTimestamp = CFAbsoluteTimeGetCurrent()
		presentingViewController.present(hud, animated: animated)
	}

	public func showLoadingIndicator() {
		hud.showLoadingIndicator()
	}

	public func showSuccess() -> Promise<Void> {
		return hud.showSuccess()
	}

	public func dismiss(animated: Bool, completion: (() -> Void)? = nil) {
		DispatchQueue.main.asyncAfter(deadline: .now() + getDelay()) {
			self.hud.dismiss(animated: animated, completion: completion)
		}
	}

	public func transformToSelfDismissingSuccess(completion: (() -> Void)? = nil) {
		DispatchQueue.main.asyncAfter(deadline: .now() + getDelay()) {
			self.hud.showSuccess().delay(0.5).then {
				self.dismiss(animated: true)
			}.then {
				completion?()
			}
		}
	}

	private func getDelay() -> TimeInterval {
		if displayTimestamp > 0 {
			return displayTimestamp - CFAbsoluteTimeGetCurrent() + minimumDisplayTime
		} else {
			return 0
		}
	}
}

public extension ProgressHUD {
	func dismiss(animated: Bool) -> Promise<Void> {
		return wrap { handler in
			self.dismiss(animated: animated, completion: handler)
		}.then { _ in
			// no-op
		}
	}

	func transformToSelfDismissingSuccess() -> Promise<Void> {
		return wrap { handler in
			self.transformToSelfDismissingSuccess(completion: handler)
		}.then { _ in
			// no-op
		}
	}
}

private class HUDController: UIViewController {
	var text: String? {
		get {
			return textLabel.text
		}
		set {
			if newValue == nil {
				textLabel.isHidden = true
			}
			textLabel.text = newValue
		}
	}

	private lazy var textLabel: UILabel = {
		let textLabel = UILabel()
		textLabel.translatesAutoresizingMaskIntoConstraints = false
		textLabel.textAlignment = .center
		textLabel.numberOfLines = 0
		textLabel.adjustsFontForContentSizeCategory = true
		textLabel.font = .preferredFont(forTextStyle: .body)
		return textLabel
	}()

	private lazy var loadingIndicator: UIActivityIndicatorView = {
		let loadingIndicator = UIActivityIndicatorView(style: .medium)
		loadingIndicator.hidesWhenStopped = true
		loadingIndicator.style = .medium
		loadingIndicator.startAnimating()
		loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
		return loadingIndicator
	}()

	private lazy var successIndicator: CheckmarkSymbol = {
		let symbol = CheckmarkSymbol(lineWidth: 3.0, animationDuration: 0.4)
		symbol.translatesAutoresizingMaskIntoConstraints = false
		symbol.isHidden = true
		return symbol
	}()

	private lazy var indicatorContainerView: UIView = {
		let indicatorContainerView = UIView()
		indicatorContainerView.translatesAutoresizingMaskIntoConstraints = false
		return indicatorContainerView
	}()

	private lazy var containerView: UIView = {
		let containerView = UIView()
		containerView.translatesAutoresizingMaskIntoConstraints = false
		containerView.backgroundColor = .secondarySystemBackground
		containerView.layer.cornerRadius = 10
		containerView.layer.masksToBounds = true
		return containerView
	}()

	private lazy var stackView: UIStackView = {
		let stackView = UIStackView()
		stackView.translatesAutoresizingMaskIntoConstraints = false
		stackView.addArrangedSubview(indicatorContainerView)
		stackView.addArrangedSubview(textLabel)
		stackView.axis = .horizontal
		stackView.spacing = 32
		stackView.distribution = .equalSpacing
		stackView.alignment = .center
		return stackView
	}()

	override func viewDidLoad() {
		super.viewDidLoad()
		view.backgroundColor = UIColor.black.withAlphaComponent(0.4)

		view.addSubview(containerView)

		containerView.addSubview(stackView)

		indicatorContainerView.addSubview(loadingIndicator)
		indicatorContainerView.addSubview(successIndicator)

		NSLayoutConstraint.activate([
			containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
			containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
			containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 52),
			containerView.leadingAnchor.constraint(greaterThanOrEqualTo: view.readableContentGuide.leadingAnchor),
			containerView.trailingAnchor.constraint(lessThanOrEqualTo: view.readableContentGuide.trailingAnchor),

			stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 32),
			stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -32),
			stackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
			stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),

			indicatorContainerView.widthAnchor.constraint(equalToConstant: 20),
			indicatorContainerView.heightAnchor.constraint(equalToConstant: 20),

			loadingIndicator.topAnchor.constraint(equalTo: indicatorContainerView.topAnchor),
			loadingIndicator.bottomAnchor.constraint(equalTo: indicatorContainerView.bottomAnchor),
			loadingIndicator.leadingAnchor.constraint(equalTo: indicatorContainerView.leadingAnchor),
			loadingIndicator.trailingAnchor.constraint(equalTo: indicatorContainerView.trailingAnchor),

			successIndicator.topAnchor.constraint(equalTo: indicatorContainerView.topAnchor),
			successIndicator.bottomAnchor.constraint(equalTo: indicatorContainerView.bottomAnchor),
			successIndicator.leadingAnchor.constraint(equalTo: indicatorContainerView.leadingAnchor),
			successIndicator.trailingAnchor.constraint(equalTo: indicatorContainerView.trailingAnchor)
		])
	}

	func showSuccess(completion: (() -> Void)? = nil) {
		UIView.animate(withDuration: 0.5, animations: ({
			self.text = nil
			self.stackView.layoutIfNeeded()
		}), completion: ({ _ in
			self.hideAllIndicators()
			self.successIndicator.isHidden = false
			self.successIndicator.startAnimation(completion: completion)
		}))
	}

	func showSuccess() -> Promise<Void> {
		return wrap { handler in
			self.showSuccess(completion: handler)
		}.then { _ in
			// no-op
		}
	}

	func showLoadingIndicator() {
		textLabel.isHidden = textLabel.text?.isEmpty ?? true
		hideAllIndicators()
		loadingIndicator.isHidden = false
	}

	private func hideAllIndicators() {
		indicatorContainerView.subviews.forEach { $0.isHidden = true }
	}

	private func addSuccessIndicatorView() {
		containerView.addSubview(successIndicator)
		NSLayoutConstraint.activate([
			successIndicator.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
			successIndicator.heightAnchor.constraint(equalToConstant: 20),
			successIndicator.widthAnchor.constraint(equalToConstant: 20),
			successIndicator.leadingAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.leadingAnchor, constant: 32),
			successIndicator.trailingAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.trailingAnchor, constant: -32)
		])
	}

	private func addLoadingIndicatorViewWithText() {
		containerView.addSubview(textLabel)
		containerView.addSubview(loadingIndicator)
		NSLayoutConstraint.activate([
			textLabel.topAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.topAnchor, constant: 16),
			textLabel.trailingAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.trailingAnchor, constant: -32),
			textLabel.bottomAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.bottomAnchor, constant: -16),

			loadingIndicator.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
			loadingIndicator.leadingAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.leadingAnchor, constant: 32),
			loadingIndicator.trailingAnchor.constraint(equalTo: textLabel.leadingAnchor, constant: -32)
		])
	}
}

private class CheckmarkSymbol: UIView {
	private let animationDuration: CFTimeInterval
	init(lineWidth: CGFloat, animationDuration: CFTimeInterval) {
		self.animationDuration = animationDuration
		super.init(frame: .zero)
		shapeLayer.fillColor = nil
		shapeLayer.lineWidth = lineWidth
		shapeLayer.strokeEnd = 0.0
		shapeLayer.strokeColor = UIColor.label.cgColor
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	private func getPath() -> UIBezierPath {
		let path = UIBezierPath()
		path.move(to: .init(x: layer.bounds.minX, y: layer.bounds.maxY * 0.54))
		path.addLine(to: .init(x: layer.bounds.maxX * 0.33, y: layer.bounds.maxY * 0.85))
		path.addLine(to: .init(x: layer.bounds.maxX * 0.95, y: layer.bounds.maxY * 0.167))
		path.lineJoinStyle = .round
		path.lineCapStyle = .round
		return path
	}

	override static var layerClass: AnyClass {
		return CAShapeLayer.self
	}

	private var shapeLayer: CAShapeLayer {
		// swiftlint:disable:next force_cast
		return layer as! CAShapeLayer
	}

	override func draw(_ rect: CGRect) {
		super.draw(rect)
		shapeLayer.path = getPath().cgPath
	}

	func startAnimation(completion: (() -> Void)? = nil) {
		CATransaction.begin()
		CATransaction.setCompletionBlock(completion)
		let pathAnimation = CABasicAnimation(keyPath: "strokeEnd")
		pathAnimation.duration = animationDuration
		pathAnimation.fromValue = 0.0
		pathAnimation.toValue = 1.0
		pathAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
		pathAnimation.fillMode = .forwards
		pathAnimation.isRemovedOnCompletion = false
		shapeLayer.add(pathAnimation, forKey: "strokeEnd")
		CATransaction.commit()
	}

	func startAnimation() -> Promise<Void> {
		return wrap { handler in
			self.startAnimation(completion: handler)
		}.then { _ in
			// no-op
		}
	}
}
