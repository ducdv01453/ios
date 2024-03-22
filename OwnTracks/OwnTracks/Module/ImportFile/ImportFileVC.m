//
//  ImportFileVC.m
//  OwnTracks
//
//  Created by duc do viet on 22/03/2024.
//  Copyright © 2024 OwnTracks. All rights reserved.
//

#import "ImportFileVC.h"
#import "Settings.h"
#import "CoreData.h"
#import "Setting+CoreDataClass.h"
#import "NavigationController.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import "Validation.h"

@interface ImportFileVC () <UIDocumentPickerDelegate>

@end

@implementation ImportFileVC

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void)showFilePicker {
    NSArray* fileUTI = [[NSArray alloc] initWithObjects:
                        @"org.owntracks.otrc",
                        @"org.owntracks.otrw",
                        @"org.owntracks.otrp",
                        @"org.owntracks.otre", nil];
    UTType* otrcType = [UTType typeWithFilenameExtension: @"otrc" conformingToType: UTTypeData];
    UIDocumentPickerViewController* documentPicker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[otrcType]];
    documentPicker.delegate = self;
    
    documentPicker.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:documentPicker animated:YES completion:nil];
}

- (IBAction)onSelectedImport:(id)sender {
    [self showFilePicker];
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
    if (dict) {
        [self configFromDictionary:dict];
    }
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    
}

- (void)configFromDictionary:(NSDictionary *)json {
    NSError *error = [Settings fromDictionary:json inMOC:CoreData.sharedInstance.mainMOC];
    [CoreData.sharedInstance sync:CoreData.sharedInstance.mainMOC];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"reload" object:nil];

    if (error) {
        NSLog(@"Error");
    }
}

@end
