//
//  FileProviderValidationServiceSource.h
//
//  Copyright © 2018 Apple. All rights reserved.
//

#if DEBUG
#import <Foundation/Foundation.h>
#import <FileProvider/FileProvider.h>

@interface FileProviderValidationServiceSource : NSObject <NSFileProviderServiceSource>

- (instancetype)initWithFileProviderExtension:(NSFileProviderExtension *)fileProviderExtension
                               itemIdentifier:(NSFileProviderItemIdentifier)itemIdentifier;

@end
#endif
