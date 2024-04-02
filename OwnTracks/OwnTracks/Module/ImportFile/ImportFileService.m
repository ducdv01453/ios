//
//  ImportFileService.m
//  OwnTracks
//
//  Created by duc do viet on 22/03/2024.
//  Copyright © 2024 OwnTracks. All rights reserved.
//

#import "ImportFileService.h"
#import "Settings.h"
#import "CoreData.h"
#import "Setting+CoreDataClass.h"
#import "NavigationController.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import "Validation.h"
#import <CocoaLumberjack/CocoaLumberjack.h>

@interface ImportFileService () <UIDocumentPickerDelegate>

@end

@implementation ImportFileService

+ (ImportFileService *)sharedInstance {
    static dispatch_once_t once = 0;
    static id sharedInstance = nil;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (void)showFilePickerFrom:(UIViewController *) sourceVC {
    NSArray* fileUTI = [[NSArray alloc] initWithObjects:
                        [UTType typeWithFilenameExtension: @"otrc" conformingToType: UTTypeData],
                        [UTType typeWithFilenameExtension: @"otrw" conformingToType: UTTypeData],
                        [UTType typeWithFilenameExtension: @"otrp" conformingToType: UTTypeData],
                        [UTType typeWithFilenameExtension: @"otre" conformingToType: UTTypeData],
                        nil];
    UIDocumentPickerViewController* documentPicker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:fileUTI];
    documentPicker.delegate = self;
    documentPicker.modalPresentationStyle = UIModalPresentationFormSheet;
    [sourceVC presentViewController:documentPicker animated:YES completion:nil];
}

// MARK: - UIDocumentPickerDelegate
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL* filePath = [urls firstObject];
    [filePath startAccessingSecurityScopedResource];
    NSError* error;
    NSData *jsonData = [[NSData alloc] initWithContentsOfURL:filePath];
    [filePath stopAccessingSecurityScopedResource];
    NSDictionary *dict = nil;
    id json = [[Validation sharedInstance] validateMessageData:jsonData];
    if (json &&
        [json isKindOfClass:[NSDictionary class]]) {
        dict = json;
    }
    NSString* processingMessage = nil;
    if (dict) {
        NSError* error = [self configFromDictionary:dict];
        if (error) {
            [self.delegate didImportSuccess:NO error:error];
        }else {
            [self.delegate didImportSuccess:YES error:nil];
        }
    }else {
        [self.delegate didImportSuccess:NO error: [NSError errorWithDomain:@"OwnTracks import" code:6969 userInfo:@{}]];
    }
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    
}

- (NSError*)configFromDictionary:(NSDictionary *)json {
    NSError *error = [Settings fromDictionary:json inMOC:CoreData.sharedInstance.mainMOC];
    [CoreData.sharedInstance sync:CoreData.sharedInstance.mainMOC];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"reload" object:nil];
    
    if (error) {
        return error;
    }
    
    return nil;
}

@end
