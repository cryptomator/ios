//
//  Snapshots.swift
//  Snapshots
//
//  Created by Philipp Schmid on 13.12.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import XCTest

class Snapshots: XCTestCase {
	var app: XCUIApplication!
	var filesApp: XCUIApplication!
	override func setUpWithError() throws {
		app = XCUIApplication()
		filesApp = XCUIApplication(bundleIdentifier: "com.apple.DocumentsApp")

		// In UI tests it is usually best to stop immediately when a failure occurs.
		continueAfterFailure = false

		switch UIDevice.current.userInterfaceIdiom {
		case .pad:
			XCUIDevice.shared.orientation = .landscapeLeft
		default:
			XCUIDevice.shared.orientation = .portrait
		}
	}

	func testSnapshots() throws {
		enableBiometrics()
		filesAppSnapshots()
		mainAppSnapshots()
	}

	private func mainAppSnapshots() {
		setupSnapshot(app, waitForAnimations: false)
		app.launch()
		switch UIDevice.current.userInterfaceIdiom {
		case .phone:
			iPhoneMainAppSnapshots()
		case .pad:
			iPadMainAppSnapshots()
		default:
			XCTFail("Device \(UIDevice.current.userInterfaceIdiom) not supported")
		}
		app.terminate()
	}

	private func iPhoneMainAppSnapshots() {
		onboardingSnapshot()

		navigateFromOnboardingToVaultList()
		vaultListSnapshot()

		navigateFromVaultListToVaultDetail()
		vaultDetailSnapshot()

		navigateFromVaultDetailToOpenExistingVault()
		cloudServicesSnapshot()
	}

	private func iPadMainAppSnapshots() {
		onboardingSnapshot()

		navigateFromOnboardingToVaultList()
		navigateFromVaultListToVaultDetail()
		vaultDetailSnapshot()

		navigateFromVaultDetailToOpenExistingVault()
		cloudServicesSnapshot()
	}

	private func onboardingSnapshot() {
		let onboardingTable = app.tables["Snapshot_OnboardingViewController"]
		XCTAssert(onboardingTable.waitForExistence(timeout: 3.0))
		snapshot("01-Onboarding")
	}

	private func navigateFromOnboardingToVaultList() {
		let onboardingTable = app.tables["Snapshot_OnboardingViewController"]
		let continueButton = onboardingTable.cells.firstMatch
		XCTAssert(continueButton.waitForIsHittable(timeout: 3.0))
		continueButton.tap()
	}

	private func vaultListSnapshot() {
		let vaultListTable = app.tables["Snapshot_VaultListViewController"]
		let workVault = vaultListTable.cells.element(boundBy: 0)
		XCTAssert(workVault.waitForIsHittable(timeout: 3.0))
		snapshot("02-VaultList")
	}

	private func navigateFromVaultListToVaultDetail() {
		let vaultListTable = app.tables["Snapshot_VaultListViewController"]
		let workVault = vaultListTable.cells.element(boundBy: 0)
		workVault.tap()
	}

	private func vaultDetailSnapshot() {
		let vaultDetailTableView = app.tables["Snapshot_VaultDetailViewController"]
		XCTAssert(vaultDetailTableView.waitForExistence(timeout: 3.0))
		snapshot("04-VaultDetail")
	}

	private func navigateFromVaultDetailToOpenExistingVault() {
		let tablesQuery = app.tables
		if UIDevice.current.userInterfaceIdiom == .phone {
			// Tap on Back
			app.navigationBars.buttons.element(boundBy: 0).tap()
		}
		// Tap on the + symbol
		app.navigationBars.buttons.element(boundBy: 1).tap()

		// Open Existing Vault
		let openExistingVaultButton = tablesQuery["Snapshot_AddVaultViewController"].buttons.element(boundBy: 1)
		XCTAssert(openExistingVaultButton.waitForIsHittable(timeout: 3.0))
		openExistingVaultButton.tap()
	}

	private func cloudServicesSnapshot() {
		let tablesQuery = app.tables
		XCTAssert(tablesQuery.staticTexts["Dropbox"].waitForIsHittable(timeout: 3.0))
		snapshot("03-CloudServices")
	}

	// MARK: Files App

	private func filesAppSnapshots() {
		app.launch()
		XCTAssert(app.wait(for: .runningForeground, timeout: 10.0))
		app.terminate()
		setupSnapshot(filesApp)
		filesApp.activate()
		switch UIDevice.current.userInterfaceIdiom {
		case .phone:
			iPhoneFilesAppSnapshots()
		case .pad:
			iPadFilesAppSnapshots()
		default:
			XCTFail("Device \(UIDevice.current.userInterfaceIdiom) not supported for Files app snapshots")
		}
		filesApp.terminate()
	}

	private func iPhoneFilesAppSnapshots() {
		enableCryptomatorInFilesApp()
		snapshotFilesOverview()

		showFilesAppUnlock()
		snapshotFilesAppUnlock()

		closeFilesAppUnlock()
		snapshotFilesAppDirectoryList()
	}

	private func iPadFilesAppSnapshots() {
		enableCryptomatorInFilesApp()
		showFilesAppUnlock()
		snapshotFilesAppUnlock()

		closeFilesAppUnlock()
		snapshotFilesAppDirectoryList()
	}

	private func enableCryptomatorInFilesApp() {
		XCTAssert(filesApp.wait(for: .runningForeground, timeout: 5.0))

		navigateFromRecentsToFilesAppOverview()

		// Tap on More Locations
		tapMoreLocationsInFilesAppOverview()

		// Enable Cryptomator as FileProvider
		let browseCollectionView = filesApp.collectionViews["Browse View"]
		let cryptomatorCell = browseCollectionView.cells["DOC.sidebar.item.Cryptomator"]
		let cryptomatorCellSwitch = cryptomatorCell.switches.firstMatch
		XCTAssert(cryptomatorCellSwitch.waitForIsHittable(timeout: 3.0))
		cryptomatorCellSwitch.tap()

		// Press Done
		tapDoneButtonInFilesAppOverview()
	}

	private func navigateFromRecentsToFilesAppOverview() {
		guard XCUIDevice.shared.orientation == .portrait else {
			return
		}
		// Tap on Browse
		filesApp.tabBars["DOC.browsingModeTabBar"].buttons.element(boundBy: 1).tap(withNumberOfTaps: 2, numberOfTouches: 1)
	}

	private func tapDoneButtonInFilesAppOverview() {
		let doneButton: XCUIElement
		switch UIDevice.current.userInterfaceIdiom {
		case .phone:
			doneButton = filesApp.navigationBars["FullDocumentManagerViewControllerNavigationBar"].buttons.firstMatch
		case .pad:
			doneButton = filesApp.navigationBars.firstMatch.buttons.element(boundBy: 1)
		default:
			XCTFail("Tap Done button in Files app overview is not supported for device: \(UIDevice.current.userInterfaceIdiom)")
			return
		}
		XCTAssert(doneButton.waitForIsHittable(timeout: 3.0))
		doneButton.tap()
	}

	private func tapMoreLocationsInFilesAppOverview() {
		let index: Int
		switch UIDevice.current.userInterfaceIdiom {
		case .phone:
			index = 2
		case .pad:
			index = 3
		default:
			XCTFail("Tap Done button in Files app overview is not supported for device: \(UIDevice.current.userInterfaceIdiom)")
			return
		}
		let moreLocationsCell = filesApp.cells.element(boundBy: index)
		XCTAssert(moreLocationsCell.waitForIsHittable(timeout: 3.0))
		moreLocationsCell.tap()
	}

	private func snapshotFilesOverview() {
		let browseCollectionView = filesApp.collectionViews["Browse View"]
		let cryptomatorCell = browseCollectionView.cells["DOC.sidebar.item.Cryptomator"]
		XCTAssert(cryptomatorCell.waitForIsHittable(timeout: 3.0))
		snapshot("05-Files-Overview")
	}

	private func showFilesAppUnlock() {
		let browseCollectionView = filesApp.collectionViews["Browse View"]
		let cryptomatorCell = browseCollectionView.cells["DOC.sidebar.item.Cryptomator"]
		// Start Cryptomator FileProvider
		cryptomatorCell.tap()

		// Unlock Screen
		let vaultUnlockTableView = filesApp.tables["Snapshot_UnlockVaultViewController"]
		XCTAssert(vaultUnlockTableView.waitForExistence(timeout: 20.0))

		let passwordField = vaultUnlockTableView.textFields.firstMatch
		passwordField.typeText("••••••••")
	}

	private func closeFilesAppUnlock() {
		filesApp.buttons["Snapshot_UnlockButton"].tap()
	}

	private func snapshotFilesAppUnlock() {
		sleep(1)
		snapshot("06-Files-UnlockWithPassword")
	}

	private func snapshotFilesAppDirectoryList() {
		let vaultRootFolderView = filesApp.collectionViews["File View"]
		XCTAssert(vaultRootFolderView.value as? String == "Icon Mode")
		let cryptomatorJPGFile = vaultRootFolderView.cells["Cryptomator, jpg"]
		XCTAssert(cryptomatorJPGFile.waitForIsHittable(timeout: 10.0))
		snapshot("07-Files-DirectoryList")
	}

	private func enableBiometrics() {
		SnapshotBiometrics.enrolled()
	}
}

extension XCUIElement {
	func waitForIsHittable(timeout: TimeInterval) -> Bool {
		return waitForPredicate(NSPredicate(format: "isHittable == true"), timeout: timeout)
	}

	private func waitForPredicate(_ predicate: NSPredicate, timeout: TimeInterval) -> Bool {
		let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
		let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
		return result == .completed
	}
}
