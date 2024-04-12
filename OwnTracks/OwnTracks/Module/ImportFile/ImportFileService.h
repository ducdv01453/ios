//
//  ImportFileService.h
//  OwnTracks
//
//  Created by duc do viet on 22/03/2024.
//  Copyright © 2024 OwnTracks. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol ImportFileServiceDelegate <NSObject>
- (void)didImportSuccess:(BOOL) success error:(NSError* __nullable) error;

@end

NS_ASSUME_NONNULL_BEGIN

@interface ImportFileService : NSObject

+ (ImportFileService *)sharedInstance;

@property (weak, nonatomic) id<ImportFileServiceDelegate> delegate;

- (void)showFilePickerFrom:(UIViewController *) sourceVC;
@end

NS_ASSUME_NONNULL_END