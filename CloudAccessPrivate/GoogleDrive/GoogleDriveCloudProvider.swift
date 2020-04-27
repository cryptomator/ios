//
//  GoogleDriveCloudProvider.swift
//  CloudAccessPrivate
//
//  Created by Philipp Schmid on 24.04.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import Foundation
import CryptomatorCloudAccess
import Promises
import GoogleAPIClientForREST

class GoogleDriveCloudProvider: CloudProvider {
    
    private let authentication: GoogleDriveCloudAuthentication
    private let rootFolderId = "root"
    private lazy var driveService : GTLRDriveService = {
       var driveService = GTLRDriveService()
        driveService.authorizer = self.authentication.authorization
        driveService.isRetryEnabled = true
        //MARK: Add retryBlocks
        //        driveService.retryBlock =
        driveService.fetcherService.isRetryEnabled = true
        //        driveService.fetcherService.retryBlock =
        return driveService
    }()
    required init(withAuthentication authentication: CloudAuthentication) {
        fatalError("not implemented yet")
    }
    
    public init(with authentication: GoogleDriveCloudAuthentication) {
        self.authentication = authentication
    }
    
    
    func fetchItemMetadata(at remoteURL: URL) -> Promise<CloudItemMetadata> {
        //MARK: Implement function
        fatalError("not implemented yet")
    }
    
    func fetchItemList(forFolderAt remoteURL: URL, withPageToken pageToken: String?) -> Promise<CloudItemList> {
        //MARK: Implement function
        fatalError("not implemented yet")
        
    }
    
    func createBackgroundDownloadTask(for file: CloudFile, with delegate: URLSessionTaskDelegate) -> Promise<URLSessionDownloadTask> {
        //MARK: Implement function
        fatalError("not implemented yet")
        
    }
    
    func createBackgroundUploadTask(for file: CloudFile, with delegate: URLSessionTaskDelegate) -> Promise<URLSessionUploadTask> {
        //MARK: Implement function
        fatalError("not implemented yet")
        
    }
    
    func createFolder(at remoteURL: URL) -> Promise<Void> {
        //MARK: Implement function
        fatalError("not implemented yet")
        
    }
    
    func deleteItem(at remoteURL: URL) -> Promise<Void> {
        //MARK: Implement function
        fatalError("not implemented yet")
        
    }
    
    func moveItem(from oldRemoteURL: URL, to newRemoteURL: URL) -> Promise<Void> {
        //MARK: Implement function
        fatalError("not implemented yet")
        
    }
    
    private func getIdentifier(for remoteURL: URL) -> Promise<String> {
        var parentFolderId = rootFolderId
        //MARK: Implement Cache-Lookup
        return Promise<String>{ fulfill, reject in
            for pathComponent in remoteURL.pathComponents {
                parentFolderId = try await(self.getFirstIdentifier(for: pathComponent, inFolderWithId: parentFolderId))
            }
            let identifier = parentFolderId
            fulfill(identifier)
        }
        
    }
    
    private func getFirstIdentifier(for foldername: String, inFolderWithId: String) -> Promise<String> {
        let query = GTLRDriveQuery_FilesList.query()
        query.q = "'\(inFolderWithId)' in parents and name contains '\(foldername)' and trashed = false"
        query.fields = "files/id, files/name"
        return Promise<String> { fulfill, reject in
            self.executeQuery(query) { (result) in
                switch result{
                case .success(let fileList as GTLRDrive_FileList):
                    for file in fileList.files ?? [GTLRDrive_File]() {
                        if file.name == foldername{
                            guard let identifier = file.identifier else {
                                return reject(GoogleDriveError.noIdentifierFound)
                            }
                            fulfill(identifier)
                        }
                    }
                    reject(CloudProviderError.itemNotFound)
                case .success(_):
                    fatalError("GTLRDriveQuery_FilesList returned no GTLRDrive_FileList") //MARK: or change to an error but if this case occur there is a serious problem with the underlying sdk
                case .failure(let error as NSError):
                    if error.domain == kGTLRErrorObjectDomain && error.code == 404 {
                        return reject(CloudProviderError.itemNotFound)
                    }
                    reject(error)
                }
            }
        }
        
    }
    
    /**
     A wrapper for the GTLRDriveQuery for a more swifty  execution with result.
     */
    private func executeQuery(_ query: GTLRDriveQuery, completion: @escaping (Result<Any, Error>) -> Void) {
        let ticket = self.driveService.executeQuery(query) { (ticket, result, error) in
            //MARK: remove ticket
            if let error = error{
                return completion(.failure(error))
            }
            assert(result != nil)
            completion(.success(result!))
        }
        //MARK: ticket add
    }
    
}
