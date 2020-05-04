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

public class GoogleDriveCloudProvider: CloudProvider {
    
    
    
    private let authentication: GoogleDriveCloudAuthentication
    private let rootFolderId = "root"
    private let folderMimeType = "application/vnd.google-apps.folder"
    private let unknownMimeType = "application/octet-stream"
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
    
    public init(with authentication: GoogleDriveCloudAuthentication) {
        self.authentication = authentication
    }
    
    
    public func fetchItemMetadata(at remoteURL: URL) -> Promise<CloudItemMetadata> {
        return resolvePath(for: remoteURL).then(fetchGTLRDriveFile).then{ file -> CloudItemMetadata in
            guard let name = file.name, let lastModifiedDate = file.modifiedTime?.date, let mimeType = file.mimeType else {
                throw CloudProviderError.itemNotFound //MARK: Discuss Error
            }
            let itemType = self.getCloudItemType(forMimeType: mimeType)
            return CloudItemMetadata(name: name, size: file.size, remoteURL: remoteURL, lastModifiedDate: lastModifiedDate, itemType: itemType)
        }
    }
    
    public func fetchItemList(forFolderAt remoteURL: URL, withPageToken pageToken: String?) -> Promise<CloudItemList> {
        precondition(remoteURL.hasDirectoryPath)
        return self.resolvePath(for: remoteURL).then{ identifier in
            return self.fetchGTLRDriveFileList(forIdentifier: identifier, withPageToken: pageToken)
        }.then{ fileList in
            let cloudItemList = try self.convertGTLRDriveFileListToCloudItemList(fileList, forFolderAt: remoteURL)
            return Promise(cloudItemList)
        }
    }
    
    public func createBackgroundDownloadTask(for file: CloudFile, with delegate: URLSessionTaskDelegate) -> Promise<URLSessionDownloadTask> {
        //MARK: Discuss if this DownloadTask should be authorized later and not directly. (For example if the download is pending for a long time the token could have expired).
        //MARK: Test current Implementation manually
        return resolvePath(for: file.metadata.remoteURL).then{ identifier -> Promise<URLRequest> in
            let query = GTLRDriveQuery_FilesGet.queryForMedia(withFileId: identifier)
            return self.createAuthorizedRequest(for: query)
        }.then{ request -> URLSessionDownloadTask in
            let config = URLSessionConfiguration.background(withIdentifier: "GoogleDriveDownload-\(file.metadata.remoteURL.absoluteString)")
            //MARK: Add here the correct containerIdentifier
            //config.sharedContainerIdentifier = ""
            let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
            let downloadTask = session.downloadTask(with: request as URLRequest)
            return downloadTask
        }
        
        
    }
    
    public func createBackgroundUploadTask(for file: CloudFile, isUpdate: Bool, with delegate: URLSessionTaskDelegate) -> Promise<URLSessionUploadTask> {
        return createUploadQuery(for: file, isUpdate: isUpdate).then{ query in
            return self.createAuthorizedRequest(for: query)
        }.then{ request -> URLSessionUploadTask in
            let config = URLSessionConfiguration.background(withIdentifier: "GoogleDriveUpload-\(file.metadata.remoteURL.absoluteString)")
            //MARK: Add here the correct containerIdentifier
            //config.sharedContainerIdentifier = ""
            let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
            let uploadTask = session.uploadTask(with: request, fromFile: file.localURL)
            return uploadTask
        }
    }
    
    public func createFolder(at remoteURL: URL) -> Promise<Void> {
        precondition(remoteURL.hasDirectoryPath)
        let parentFolderRemoteURL = remoteURL.deletingLastPathComponent()
        let foldername = remoteURL.lastPathComponent
        return Promise<Void>(on: .global()){ fulfill, reject in
            let parentIdentifier = try await(self.resolvePath(for: parentFolderRemoteURL))
            do{
                let _ = try await(self.getFirstIdentifier(forItemWithName: foldername, inFolderWithId: parentIdentifier))
                reject(CloudProviderError.itemAlreadyExists)
            } catch CloudProviderError.itemNotFound {
                let _ = try await(self.createFolder(name: foldername, parentIdentifier: parentIdentifier))
                fulfill(())
            }
        }
    }
    
    public func deleteItem(at remoteURL: URL) -> Promise<Void> {
        return resolvePath(for: remoteURL).then(deleteItem)
    }
    
    public func moveItem(from oldRemoteURL: URL, to newRemoteURL: URL) -> Promise<Void> {
        precondition(oldRemoteURL.hasDirectoryPath == newRemoteURL.hasDirectoryPath)
        let metadata = GTLRDrive_File()
        metadata.name = newRemoteURL.lastPathComponent
        
        return Promise<Void>(on: .global()){ fulfill, reject in
            do{
                let _ = try await(self.resolvePath(for: newRemoteURL))
                reject(CloudProviderError.itemAlreadyExists)
            } catch CloudProviderError.itemNotFound {
                let itemIdentifier = try await(self.resolvePath(for: oldRemoteURL))
                
                let query = GTLRDriveQuery_FilesUpdate.query(withObject: metadata, fileId: itemIdentifier, uploadParameters: nil)
                if !self.onlyItemNameChangedBetween(oldRemoteURL: oldRemoteURL, and: newRemoteURL) {
                    let newParentRemoteURL = newRemoteURL.deletingLastPathComponent()
                    let newParentIdentifier = try await(self.resolvePath(for: newParentRemoteURL))
                    
                    let oldParentRemoteURL = oldRemoteURL.deletingLastPathComponent()
                    let oldParentIdentifier = try await(self.resolvePath(for: oldParentRemoteURL))
                    query.addParents = newParentIdentifier
                    query.removeParents = oldParentIdentifier
                }
                self.executeQuery(query) { result in
                    switch result{
                    case .success(_):
                        fulfill(())
                    case .failure(let error):
                        reject(error)
                    }
                }
            }
            
        }
    }
    
    //MARK: Resolve remote URL to Google Drive Item Identifier
    
    func resolvePath(for remoteURL: URL) -> Promise<String> {
        
        //MARK: Change Cache to DB for thread safety
        var cachedIdentifier: String?
        var urlToCheckForCache = remoteURL
        var removedComponents = 0
        while(cachedIdentifier == nil && removedComponents < remoteURL.pathComponents.count - 1) {
            //MARK: cachedIdentifier lookup in DB
            urlToCheckForCache.deleteLastPathComponent()
            removedComponents += 1
            print("urlToCheckForCache: \(urlToCheckForCache)")
            //MARK: Only to debug before DB Cache
            if (urlToCheckForCache == URL(fileURLWithPath: "/"))
            {
                cachedIdentifier = "root"
            }
        }
        if urlToCheckForCache != remoteURL {
            return traverseThroughPath(from: urlToCheckForCache, to: remoteURL, withStartIdentifier: cachedIdentifier!)
        }
        return Promise(cachedIdentifier!)
        
    }
    
    private func getFirstIdentifier(forItemWithName itemName: String, inFolderWithId: String) -> Promise<String> {
        let query = GTLRDriveQuery_FilesList.query()
        print("called getFirstIdentifier with: itemName: \(itemName) and inFolderWithId: \(inFolderWithId)")
        query.q = "'\(inFolderWithId)' in parents and name contains '\(itemName)' and trashed = false"
        query.fields = "files(id, name)"
        return Promise<String> { fulfill, reject in
            self.executeQuery(query) { (result) in
                switch result{
                case .success(let fileList as GTLRDrive_FileList):
                    for file in fileList.files ?? [GTLRDrive_File]() {
                        print("filename:\(file.name)")
                        if file.name == itemName{
                            guard let identifier = file.identifier else {
                                return reject(GoogleDriveError.noIdentifierFound)
                            }
                            fulfill(identifier)
                        }
                    }
                    reject(CloudProviderError.itemNotFound)
                case .success(_):
                    //MARK: or change to an error but if this case occur there is a serious problem with the underlying sdk
                    fatalError("GTLRDriveQuery_FilesList returned no GTLRDrive_FileList")
                case .failure(let error as NSError):
                    if error.domain == kGTLRErrorObjectDomain && error.code == 404 {
                        return reject(CloudProviderError.itemNotFound)
                    }
                    reject(error)
                }
            }
        }
    }
    
    //MARK: Operations with Google Drive Item Identifier
    /**
        Execute Query without the wrapper as deleteItem result is always nil
     */
    private func deleteItem(withIdentifier identifier: String) -> Promise<Void> {
        let query = GTLRDriveQuery_FilesDelete.query(withFileId: identifier)
        return Promise<Void>{ fulfill, reject in
            self.driveService.executeQuery(query) { (ticket, _, error) in
                //MARK: remove ticket
                guard error == nil else{
                    return reject(error!)
                }
                fulfill(())
            }
        }
    }
    
    
    private func fetchGTLRDriveFileList(forIdentifier identifier: String, withPageToken pageToken: String?) -> Promise<GTLRDrive_FileList> {
        let query = GTLRDriveQuery_FilesList.query()
        query.q = "'\(identifier)' in parents and trashed = false"
        query.pageSize = 1000
        query.pageToken = pageToken
        query.fields = "nextPageToken, files(id,mimeType,modifiedTime,name,size)"
        return Promise<GTLRDrive_FileList>{ fulfill, reject in
            self.executeQuery(query) { (result) in
                switch result{
                case .success(let fileList as GTLRDrive_FileList):
                    fulfill(fileList)
                case .success(_):
                    //MARK: or change to an error but if this case occur there is a serious problem with the underlying sdk
                    fatalError("GTLRDriveQuery_FilesList returned no GTLRDrive_FileList")
                case .failure(let error):
                    reject(error)
                }
            }
        }
    }
    
    private func fetchGTLRDriveFile(forItemIdentifier itemIdentifier: String) -> Promise<GTLRDrive_File> {
        let query = GTLRDriveQuery_FilesGet.query(withFileId: itemIdentifier)
        query.fields = "modifiedTime, size, mimeType"
        return Promise<GTLRDrive_File>{ fulfill, reject in
            self.executeQuery(query) { result in
                switch result{
                case .success(let file as GTLRDrive_File):
                    fulfill(file)
                case .success(_):
                    //MARK: or change to an error but if this case occur there is a serious problem with the underlying sdk
                    fatalError("GTLRDriveQuery_FilesGet returned no GTLRDrive_File")
                case .failure(let error):
                    reject(error)
                }
            }
        }
    }
    
    //MARK: Helper
    
    /**
     A wrapper for the GTLRDriveQuery for a more swifty  execution with result.
     */
    private func executeQuery(_ query: GTLRDriveQuery, completion: @escaping (Result<Any, Error>) -> Void) {
        let ticket = self.driveService.executeQuery(query) { (ticket, result, error) in
            print("executeQuery Wrapper")
            //MARK: remove ticket
            if let error = error{
                return completion(.failure(error))
            }
            assert(result != nil)
            completion(.success(result!))
        }
        //MARK: ticket add
    }
    
    func getCloudItemType(forMimeType mimeType: String) -> CloudItemType {
        if mimeType == folderMimeType{
            return .folder
        }
        return .file
    }
    
    func convertGTLRDriveFileListToCloudItemList(_ fileList: GTLRDrive_FileList, forFolderAt remoteURL: URL) throws -> CloudItemList {
        assert(remoteURL.hasDirectoryPath)
        var items = [CloudItemMetadata]()
        try fileList.files?.forEach{ file in
            guard let name = file.name, let lastModifiedDate = file.modifiedTime?.date, let mimeType = file.mimeType else{
                throw CloudProviderError.itemNotFound
            }
            let itemType = getCloudItemType(forMimeType: mimeType)
            let remoteItemURL = remoteURL.appendingPathComponent(name, isDirectory: itemType == .folder)
            
            let itemMetadata = CloudItemMetadata(name: name, size: file.size, remoteURL: remoteItemURL, lastModifiedDate: lastModifiedDate, itemType: itemType)
            items.append(itemMetadata)
        }
        let cloudItemList = CloudItemList(items: items, nextPageToken: fileList.nextPageToken)
        return cloudItemList
    }
    
    func onlyItemNameChangedBetween(oldRemoteURL: URL, and newRemoteURL: URL) -> Bool {
        let oldRemoteURLWithoutItemName = oldRemoteURL.deletingLastPathComponent()
        let newRemoteURLWithoutItemName = newRemoteURL.deletingLastPathComponent()
        return oldRemoteURLWithoutItemName == newRemoteURLWithoutItemName
    }
    
    
    private func createFolder(name: String, parentIdentifier: String) -> Promise<Void> {
        let metadata = GTLRDrive_File()
        metadata.name = name
        metadata.parents = [parentIdentifier]
        metadata.mimeType = folderMimeType
        let query = GTLRDriveQuery_FilesCreate.query(withObject: metadata, uploadParameters: nil)
        return Promise<Void>{ fulfill, reject in
            self.executeQuery(query) { result in
                switch result{
                case .success(let folder as GTLRDrive_File):
                    guard let identifier = folder.identifier else{
                        return reject(GoogleDriveError.noIdentifierFound)
                    }
                    //MARK: Cache here the identifier
                    fulfill(())
                case .success(_):
                    //MARK: or change to an error but if this case occur there is a serious problem with the underlying sdk
                    fatalError("GTLRDriveQuery_FilesCreate returned no GTLRDrive_File")
                case .failure(let error):
                    reject(error)
                }
            }
        }
    }
    //MARK: Change the function name to something more appropriate
    
    private func traverseThroughPath(from startRemoteURL: URL, to endRemoteURL:URL, withStartIdentifier startIdentifier: String) -> Promise<String> {
        assert(startRemoteURL.pathComponents.count < endRemoteURL.pathComponents.count)
        assert(startRemoteURL.hasDirectoryPath)
        
        let startIndex = startRemoteURL.pathComponents.count
        let endIndex = endRemoteURL.pathComponents.count
        
        var parentIdentifier = startIdentifier
        return Promise(on: .global()) { fulfill, _ in
            for i in startIndex..<endIndex {
                let itemName = endRemoteURL.pathComponents[i]
                print("itemName: \(itemName)")
                parentIdentifier = try await(self.getFirstIdentifier(forItemWithName: itemName, inFolderWithId: parentIdentifier))
            }
            print("fulfill with:\(parentIdentifier)")
            fulfill(parentIdentifier)
        }
    }
    
    private func createUploadQuery(for file: CloudFile, isUpdate: Bool) -> Promise<GTLRDriveQuery> {
        if isUpdate{
            return createUploadQuery(forExisting: file)
        } else {
            return createUploadQuery(forNew: file)
        }
    }
    
    private func createUploadQuery(forExisting file: CloudFile) -> Promise<GTLRDriveQuery> {
        return resolvePath(for: file.metadata.remoteURL).then{ identifier -> GTLRDriveQuery in
            let metadata = GTLRDrive_File()
            metadata.name = file.metadata.name
            let uploadParameters = GTLRUploadParameters(fileURL: file.localURL, mimeType: self.unknownMimeType)
            let query = GTLRDriveQuery_FilesUpdate.query(withObject: metadata, fileId: identifier, uploadParameters: uploadParameters)
            return query
        }
    }
    
    private func createUploadQuery(forNew file: CloudFile) -> Promise<GTLRDriveQuery> {
        return Promise<GTLRDriveQuery>(on: .global()){ fulfill, reject in
            do{
                let _ = try await(self.resolvePath(for: file.metadata.remoteURL))
                reject(CloudProviderError.itemAlreadyExists)
            } catch CloudProviderError.itemNotFound {
                let metadata = GTLRDrive_File()
                metadata.name = file.metadata.name
                let uploadParameters = GTLRUploadParameters(fileURL: file.localURL, mimeType: self.unknownMimeType)
                let query = GTLRDriveQuery_FilesCreate.query(withObject: metadata, uploadParameters: uploadParameters)
                fulfill(query)
            }
        }
    }
    
    private func createAuthorizedRequest(for query: GTLRDriveQuery) -> Promise<URLRequest> {
        let request = driveService.request(for: query)
        return Promise<URLRequest>{ fulfill, reject in
            self.authentication.authorization?.authorizeRequest(request, completionHandler: { error in
                guard error == nil else{
                    return reject(error!) //MARK: Maybe add here better Error Handling -> CloudAuthErrors..
                }
                fulfill(request as URLRequest)
            })
        }
    }
    
    
}
