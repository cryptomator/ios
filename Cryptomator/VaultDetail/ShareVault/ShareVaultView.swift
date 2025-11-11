//
//  ShareVaultView.swift
//  Cryptomator
//
//  Created by Majid Achhoud on 24.10.25.
//  Copyright © 2025 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import SwiftUI
import UIKit

struct ShareVaultView: View {
	@ObservedObject var viewModel: ShareVaultViewModel
	var onOpenURL: ((URL) -> Void)?

	var body: some View {
		ZStack {
			Color.cryptomatorBackground
				.ignoresSafeArea()

			VStack {
				ScrollView {
					VStack(spacing: 0) {
						Image(viewModel.logoImageName)
							.resizable()
							.scaledToFit()
							.frame(height: 44)
							.padding(.top, 32)

						Image("cryptomator-hub")
							.resizable()
							.scaledToFit()
							.aspectRatio(1 / 0.7, contentMode: .fit)
							.clipShape(RoundedRectangle(cornerRadius: 12))
							.padding(.top, 32)
							.padding(.horizontal)

						Text(viewModel.headerTitle)
							.font(.title3)
							.multilineTextAlignment(.center)
							.padding(.top, 24)
							.padding(.horizontal, 32)

						if let subtitle = viewModel.headerSubtitle {
							Text(subtitle)
								.font(.subheadline)
								.foregroundColor(.secondary)
								.multilineTextAlignment(.leading)
								.frame(maxWidth: .infinity, alignment: .leading)
								.padding(.top, 16)
								.padding(.horizontal, 32)
						}

						if let features = viewModel.featuresText {
							Text(features)
								.font(.subheadline)
								.foregroundColor(.secondary)
								.multilineTextAlignment(.center)
								.padding(.top, 8)
								.padding(.horizontal, 32)
						}

						if let steps = viewModel.hubSteps {
							VStack(spacing: 16) {
								ForEach(Array(steps.enumerated()), id: \.offset) { _, step in
									HStack(alignment: .top, spacing: 12) {
										Image(systemName: step.0)
											.foregroundColor(.cryptomatorPrimary)
											.frame(width: 24, height: 24)

										Text(step.1)
											.font(.subheadline)
											.foregroundColor(.secondary)
											.multilineTextAlignment(.leading)
											.frame(maxWidth: .infinity, alignment: .leading)
									}
								}
							}
							.padding(.top, 20)
							.padding(.horizontal, 32)
						}

						if let footerText = viewModel.footerText,
						   let docsButtonTitle = viewModel.docsButtonTitle,
						   let docsURL = viewModel.docsURL {
							VStack(spacing: 0) {
								(Text(footerText)
									.foregroundColor(.secondary) +
									Text(" ") +
									Text(docsButtonTitle)
									.foregroundColor(.blue)
									.underline() +
									Text(".")
									.foregroundColor(.secondary))
									.font(.footnote)
									.multilineTextAlignment(.center)
									.onTapGesture {
										onOpenURL?(docsURL)
									}
							}
							.padding(.top, 32)
							.padding(.horizontal, 32)
							.padding(.bottom, 24)
						} else {
							Spacer()
								.frame(height: 24)
						}
					}
				}

				if let url = viewModel.forTeamsURL {
					Button(
						action: {
							onOpenURL?(url)
						},
						label: {
							Text(viewModel.forTeamsButtonTitle)
								.font(.headline)
								.foregroundColor(.white)
								.frame(maxWidth: .infinity)
								.frame(height: 50)
								.background(Color.cryptomatorPrimary)
								.clipShape(RoundedRectangle(cornerRadius: 12))
						}
					)
					.padding(.horizontal, 16)
					.padding(.bottom, 16)
				}
			}
		}
	}
}
