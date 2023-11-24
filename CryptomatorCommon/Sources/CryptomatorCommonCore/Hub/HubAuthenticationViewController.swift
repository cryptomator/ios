import Combine
import Foundation
import SwiftUI

/**
 ViewController for the `HubAuthenticationView`.

 This ViewController build the bridge between UIKit and the SwiftUI `HubAuthenticationView`.
 This bridge is needed to show the tool bar items of `HubAuthenticationView` in a UIKit `UINavigationController`.
 */
public class HubAuthenticationViewController: UIViewController {
	private let viewModel: HubAuthenticationViewModel
	private var cancellables = Set<AnyCancellable>()

	public init(viewModel: HubAuthenticationViewModel) {
		self.viewModel = viewModel
		super.init(nibName: nil, bundle: nil)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override public func viewDidLoad() {
		super.viewDidLoad()
		title = LocalizedString.getValue("hubAuthentication.title")

		setupToolBar()
		setupSwiftUIView()
	}

	private func setupSwiftUIView() {
		let child = UIHostingController(rootView: HubAuthenticationView(viewModel: viewModel))
		addChild(child)
		view.addSubview(child.view)
		child.didMove(toParent: self)
		child.view.translatesAutoresizingMaskIntoConstraints = false
		NSLayoutConstraint.activate(child.view.constraints(equalTo: view))
	}

	private func setupToolBar() {
		if let initialState = viewModel.authenticationFlowState {
			updateToolbar(state: initialState)
		}

		viewModel.$authenticationFlowState
			.compactMap { $0 }
			.receive(on: DispatchQueue.main)
			.sink(receiveValue: { [weak self] in
				self?.updateToolbar(state: $0)
			})
			.store(in: &cancellables)
	}

	/**
	 Updates the `UINavigationItem` based on the given `state`.
	 - Note: This solution is far from ideal as we need to update the content of the tool bar in two places, i.e. in this method and inside the SwiftUI itself. Otherwise the behavior can differ when used inside a UINavigationController and a "SwiftUI native" `NavigationView`/ `NavigationStackView`.
	 */
	private func updateToolbar(state: HubAuthenticationViewModel.State) {
		switch state {
		case .deviceRegistration:
			let registerButton = UIBarButtonItem(title: "Register", style: .done, target: self, action: #selector(registerButtonTapped))
			navigationItem.rightBarButtonItem = registerButton
		default:
			navigationItem.rightBarButtonItem = nil
		}
	}

	@objc private func registerButtonTapped() {
		Task { await viewModel.register() }
	}
}
