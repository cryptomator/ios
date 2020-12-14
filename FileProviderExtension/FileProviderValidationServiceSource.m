//
//  FileProviderValidationServiceSource.m
//
//  Copyright © 2018 Apple. All rights reserved.
//

#if DEBUG
#import "FileProviderValidationServiceSource.h"

NSFileProviderServiceName NSFileProviderValidationServiceV1Name = @"com.apple.FileProvider.ValidationV1";

typedef NSString * NSFileProviderValidationOption NS_EXTENSIBLE_STRING_ENUM;
// which container to use for validation; defaults to NSFileProviderRootContainerItemIdentifier
NSFileProviderValidationOption NSFileProviderValidationOptionAlternateRootContainer = @"AlternateRootContainer";
// whether the provider is expected to upload/download from a server; defaults to YES
NSFileProviderValidationOption NSFileProviderValidationOptionIsSyncingProvider = @"IsSyncingProvider";

@protocol NSFileProviderValidationServiceV1
// Implement this method to enable validation of the provider. You must call the completion handler with YES for your
// provider to be shown as eligible in the validation app.
- (void)validation_allowValidation:(void (^)(BOOL shouldAllow, NSDictionary <NSFileProviderValidationOption, id> * _Nullable options))completionHandler;

// Implement this method to evict the item from your local cache. The item is expected to be in state uploaded = YES,
// downloaded = NO afterwards. If you do not support non-local items, call the completion with
// [NSError errorWithDomain:NSCocoaErrorDomain code:NSFeatureUnsupportedError userInfo:nil].
- (void)validation_evictDocumentWithCompletionHandler:(void (^)(NSError * _Nullable error))completionHandler;

// Implement this method to share the item to another account. The item is expected to be in state isShared = YES afterwards
// If you do not support shared items, call the completion with
// [NSError errorWithDomain:NSCocoaErrorDomain code:NSFeatureUnsupportedError userInfo:nil].
- (void)validation_shareDocumentWithCompletionHandler:(void (^)(NSError * _Nullable error))completionHandler;
@end

@interface FileProviderValidationServiceSource () <NSXPCListenerDelegate, NSFileProviderValidationServiceV1>
{
    NSFileProviderExtension *_fileProviderExtension;
    NSFileProviderItemIdentifier _itemIdentifier;
    NSOperationQueue *_operationQueue;
    NSHashTable *_listeners;
}
@end

@implementation FileProviderValidationServiceSource

- (instancetype)initWithFileProviderExtension:(NSFileProviderExtension *)fileProviderExtension
                               itemIdentifier:(NSFileProviderItemIdentifier)itemIdentifier
{
    if (self = [super init]) {
        _itemIdentifier = itemIdentifier;
        _fileProviderExtension = fileProviderExtension;
        _listeners = [NSHashTable hashTableWithOptions:NSHashTableStrongMemory];
    }
    return self;
}


- (NSFileProviderServiceName)serviceName
{
    return NSFileProviderValidationServiceV1Name;
}

- (nullable NSXPCListenerEndpoint *)makeListenerEndpointAndReturnError:(NSError **)error
{
    NSXPCListenerEndpoint *endpoint;
    NSXPCListener *listener = [NSXPCListener anonymousListener];
    listener.delegate = self;
    endpoint = listener.endpoint;

    [listener resume];

    @synchronized (self) {
        [_listeners addObject:listener];
    }

    return endpoint;
}

#pragma mark NSXPCListenerDelegate

- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection
{
    newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(NSFileProviderValidationServiceV1)];
    newConnection.exportedObject    = self;

    @synchronized (self) {
        [_listeners removeObject:listener];
    }

    __weak typeof(newConnection) wConnection = newConnection;

    newConnection.invalidationHandler = ^{
        //LogDebug("collaboration service source connection invalidated");
        [listener invalidate];
    };

    newConnection.interruptionHandler = ^{
        //LogDebug("collaboration service source connection interrupted");
        [wConnection invalidate];
    };

    [newConnection resume];

    return YES;
}
    
#pragma mark NSFileProviderValidationServiceV1

- (void)validation_evictDocumentWithCompletionHandler:(void (^)(NSError * _Nullable))completionHandler
{
    completionHandler(nil);
}

- (void)validation_shareDocumentWithCompletionHandler:(void (^)(NSError * _Nullable error))completionHandler
{
    completionHandler([NSError errorWithDomain:NSCocoaErrorDomain code:NSFeatureUnsupportedError userInfo:nil]);
}

- (void)validation_allowValidation:(void (^)(BOOL, NSDictionary<NSFileProviderValidationOption,id> * _Nullable))completionHandler
{
	return completionHandler(YES, @{ NSFileProviderValidationOptionIsSyncingProvider : @(YES) });
}

@end
#endif
