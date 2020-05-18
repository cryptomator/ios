//
//  ViewController.swift
//  GoogleDriveManualTest
//
//  Created by Philipp Schmid on 27.04.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CloudAccessPrivate
import CryptomatorCloudAccess
import Foundation
import Promises
import UIKit

class ViewController: UIViewController, URLSessionDownloadDelegate, URLSessionTaskDelegate {
	func urlSession(_: URLSession, downloadTask _: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
		print("filedownloaded to: \(location.path)")
	}

	func urlSession(_: URLSession, task: URLSessionTask, didCompleteWithError _: Error?) {
		if task is URLSessionUploadTask {
			print("upload finished")
		}
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		// Do any additional setup after loading the view.

		let authentication = GoogleDriveCloudAuthentication()
		let provider = GoogleDriveCloudProvider(with: authentication)
		let test = URL(fileURLWithPath: "/Test/", isDirectory: true)
		authentication.isAuthenticated().then { authenticated in
			if authenticated {
				return Promise(())
			} else {
				return authentication.authenticate(from: self)
			}
		}.then { () -> Promise<Void> in
			print("authenticated")
			return self.fetchItemList(with: provider)
		}.then { () -> Promise<Void> in
			print("authenticated")
			return self.fetchItemList(with: provider)
		}.then {
			provider.fetchItemMetadata(at: test)
		}.then { metadata in
			print(metadata.name)
		}
		/* .then{ () -> Promise<Void> in
		     return self.deleteItem(with: authentication)
		 } */
		/* .then{
		     return self.createFolder(with: authentication)
		 } */
		/* .then{
		     return self.renameWithMoveItem(with: authentication)
		 } */
		/* .then{
		     return self.realMoveItem(with: authentication)
		 } */
		/* .then{
		     return self.realMoveItemWithRename(with: authentication)
		 } */
		/* .then{
		         return authentication.deauthenticate()
		 }*/ /* .then{
		     return self.startDownload(with: authentication)
		 } */ .catch { error in
			print("error: \(error)")
		}
	}

	private func fetchItemList(with provider: CloudProvider) -> Promise<Void> {
		var startTime = CFAbsoluteTimeGetCurrent()

		let testURL = URL(fileURLWithPath: "/Test/", isDirectory: true)
		print(testURL.absoluteString)
		print(testURL.hasDirectoryPath)
		return provider.fetchItemList(forFolderAt: testURL, withPageToken: nil).then { cloudItemList in
			let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
			print("Time elapsed for fetchFileList: \(timeElapsed) s.")
			print("fetched cloudItemList")
			for item in cloudItemList.items {
				print("item: \(item.name)")
			}
			return Promise(())
		}
	}

	private func deleteItem(with authentication: GoogleDriveCloudAuthentication) -> Promise<Void> {
		let provider = GoogleDriveCloudProvider(with: authentication)
		let testURL = URL(fileURLWithPath: "/Test/FolderToDelete/", isDirectory: true)
		print(testURL.absoluteString)
		print(testURL.hasDirectoryPath)
		return provider.deleteItem(at: testURL)
	}

	private func createFolder(with authentication: GoogleDriveCloudAuthentication) -> Promise<Void> {
		let provider = GoogleDriveCloudProvider(with: authentication)
		let testURL = URL(fileURLWithPath: "/Test/FolderToCreate/", isDirectory: true)
		print(testURL.absoluteString)
		print(testURL.hasDirectoryPath)
		return provider.createFolder(at: testURL)
	}

	private func renameWithMoveItem(with authentication: GoogleDriveCloudAuthentication) -> Promise<Void> {
		let provider = GoogleDriveCloudProvider(with: authentication)
		let testURL = URL(fileURLWithPath: "/Test/Folder1/test.txt", isDirectory: false)
		let newTestURL = URL(fileURLWithPath: "/Test/Folder1/testRenamed.txt", isDirectory: false)
		print(testURL.absoluteString)
		print(testURL.hasDirectoryPath)
		return provider.moveItem(from: testURL, to: newTestURL)
	}

	private func realMoveItem(with authentication: GoogleDriveCloudAuthentication) -> Promise<Void> {
		let provider = GoogleDriveCloudProvider(with: authentication)
		let testURL = URL(fileURLWithPath: "/Test/Folder1/testRenamed.txt", isDirectory: false)
		let newTestURL = URL(fileURLWithPath: "/Test/Folder2/testRenamed.txt", isDirectory: false)
		print(testURL.absoluteString)
		print(testURL.hasDirectoryPath)
		return provider.moveItem(from: testURL, to: newTestURL)
	}

	private func realMoveItemWithRename(with authentication: GoogleDriveCloudAuthentication) -> Promise<Void> {
		let provider = GoogleDriveCloudProvider(with: authentication)
		let testURL = URL(fileURLWithPath: "/Test/Folder2/testRenamed.txt", isDirectory: false)
		let newTestURL = URL(fileURLWithPath: "/Test/Folder1/test.txt", isDirectory: false)
		print(testURL.absoluteString)
		print(testURL.hasDirectoryPath)
		return provider.moveItem(from: testURL, to: newTestURL)
	}
}
