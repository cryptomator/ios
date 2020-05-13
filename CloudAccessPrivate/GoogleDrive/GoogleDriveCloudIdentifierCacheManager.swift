//
//  GoogleDriveCloudIdentifierCacheManager.swift
//  CloudAccessPrivate
//
//  Created by Philipp Schmid on 11.05.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import Foundation
import GRDB
class GoogleDriveCloudIdentifierCacheManager {
    private let inMemoryDB: DatabaseQueue
    
    init?() {
        self.inMemoryDB = DatabaseQueue()
        do{
            try inMemoryDB.write{ db in
                try db.create(table: GoogleDriveCachedIdentifier.databaseTableName) { table in
                    table.column("itemIdentifier", .text)
                    table.column("remoteURL", .text)
                    table.primaryKey(["remoteURL"])
                }
            }
            try cacheIdentifier("root", for: URL(fileURLWithPath: "/"))
        } catch {
            return nil
        }
    }
    
    func cacheIdentifier(_ identifier: String, for remoteURL: URL) throws {
        try inMemoryDB.write{ db in
            if let cachedIdentifier = try GoogleDriveCachedIdentifier.fetchOne(db, key: ["remoteURL" : remoteURL.absoluteString]){
                cachedIdentifier.itemIdentifier = identifier
                try cachedIdentifier.updateChanges(db)
            } else {
                let newCachedIdentifier = GoogleDriveCachedIdentifier(itemIdentifier: identifier, remoteURL: remoteURL)
                try newCachedIdentifier.insert(db)
            }
        }
    }
    
    func getIdentifier(for remoteURL: URL) -> String? {
        try? inMemoryDB.read{ db in
            let cachedIdentifier = try GoogleDriveCachedIdentifier.fetchOne(db, key: ["remoteURL" : remoteURL.absoluteString])
            return cachedIdentifier?.itemIdentifier
        }
    }
    
    func uncacheIdentifier(for remoteURL: URL) throws {
        try inMemoryDB.write{ db in
            if let cachedIdentifier = try GoogleDriveCachedIdentifier.fetchOne(db, key: ["remoteURL" : remoteURL.absoluteString]) {
                try cachedIdentifier.delete(db)
            }
        }
    }
}
