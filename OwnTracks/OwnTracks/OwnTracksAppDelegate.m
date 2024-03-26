//
//  OwnTracksAppDelegate.m
//  OwnTracks
//
//  Created by Christoph Krey on 03.02.14.
//  Copyright © 2014-2024  OwnTracks. All rights reserved.
//

#import "OwnTracksAppDelegate.h"
#import <UserNotifications/UserNotifications.h>
#import <BackgroundTasks/BackgroundTasks.h>

#import "CoreData.h"
#import "Setting+CoreDataClass.h"
#import "History+CoreDataClass.h"
#import "Settings.h"
#import "OwnTracking.h"
#import "Tours.h"
#import "ConnType.h"
#import "NSNumber+decimals.h"
#import "Validation.h"

#import "OwnTracksSendNowIntent.h"
#import "OwnTracksChangeMonitoringIntent.h"
#import "OwnTracksTagIntent.h"
#import "OwnTracksPointOfInterestIntent.h"
#import "FlicButtonServices.h"
#import <SideMenu-Swift.h>
#import "ViewController.h"
#import "OwnTracksLeftMenuVC.h"

static const DDLogLevel ddLogLevel = DDLogLevelInfo;

// experimental code for APNS
#define APNS FALSE

@interface OwnTracksAppDelegate()

@property (nonatomic) UIBackgroundTaskIdentifier backgroundTask;
@property (strong, nonatomic) NSString *backgroundFetchCheckMessage;

@property (strong, nonatomic) BGTaskScheduler *bgTaskScheduler;
@property (strong, nonatomic) BGTask *bgTask;

@property (strong, nonatomic) CoreData *coreData;
@property (strong, nonatomic) CMPedometer *pedometer;

@property (strong, nonatomic) NSUserActivity *sendNowActivity;

#define BACKGROUND_DISCONNECT_AFTER 15.0
#define BACKGROUND_HOLD_FOR 10.0
@property (strong, nonatomic) NSTimer *disconnectTimer;
@property (strong, nonatomic) NSTimer *holdTimer;
@property (strong, nonatomic) NSTimer *bgTimer;



@end

@implementation OwnTracksAppDelegate

- (void)setShortcutItems {
    UIApplication *application = [UIApplication sharedApplication];
    UIApplicationShortcutItem *move =
    [[UIApplicationShortcutItem alloc]
     initWithType:@"org.mqttitude.MQTTitude.movemode"
     localizedTitle:NSLocalizedString(@"Switch to Move Monitoring Mode",
                                      @"Shortcut Switch to Move Monitoring Mode")
     localizedSubtitle:nil
     icon:[UIApplicationShortcutIcon iconWithSystemImageName:@"forward.fill"]
     userInfo:nil];
    UIApplicationShortcutItem *significant =
    [[UIApplicationShortcutItem alloc]
     initWithType:@"org.mqttitude.MQTTitude.significantmode"
     localizedTitle:NSLocalizedString(@"Switch to Significant Changes Monitoring Mode",
                                      @"Shortcut Switch to Significant Changes Monitoring Mode")
     localizedSubtitle:nil
     icon:[UIApplicationShortcutIcon iconWithSystemImageName:@"play.fill"]
     userInfo:nil];
    UIApplicationShortcutItem *manual =
    [[UIApplicationShortcutItem alloc]
     initWithType:@"org.mqttitude.MQTTitude.manualmode"
     localizedTitle:NSLocalizedString(@"Switch to Manual Monitoring Mode",
                                      @"Shortcut Switch to Manual Monitoring Mode")
     localizedSubtitle:nil
     icon:[UIApplicationShortcutIcon iconWithSystemImageName:@"pause.fill"]
     userInfo:nil];
    UIApplicationShortcutItem *quiet =
    [[UIApplicationShortcutItem alloc]
     initWithType:@"org.mqttitude.MQTTitude.quietmode"
     localizedTitle:NSLocalizedString(@"Switch to Quiet Monitoring Mode",
                                      @"Shortcut Switch to Quiet Monitoring Mode")
     localizedSubtitle:nil
     icon:[UIApplicationShortcutIcon iconWithSystemImageName:@"stop.fill"]
     userInfo:nil];
    
    application.shortcutItems = @[quiet, manual, significant, move];
}


#pragma ApplicationDelegate

- (void)buildMenuWithBuilder:(id<UIMenuBuilder>)builder  API_AVAILABLE(ios(13.0)){
    [builder removeMenuForIdentifier:UIMenuHelp];
}

- (BOOL)application:(UIApplication *)application willFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
#ifdef DEBUG
    [DDLog addLogger:[DDOSLogger sharedInstance] withLevel:DDLogLevelVerbose];
#endif
    [DDLog addLogger:[DDOSLogger sharedInstance] withLevel:DDLogLevelWarning];
    
    self.fl = [[DDFileLogger alloc] init];
    NSISO8601DateFormatter *isoFormatter = [[NSISO8601DateFormatter alloc] init];
    [isoFormatter setFormatOptions:
     NSISO8601DateFormatWithFullDate |
     NSISO8601DateFormatWithFullTime |
     NSISO8601DateFormatWithFractionalSeconds];
    self.fl.logFormatter = [[DDLogFileFormatterDefault alloc]
                            initWithDateFormatter:(NSDateFormatter *)isoFormatter];
    [DDLog addLogger:self.fl withLevel:DDLogLevelVerbose];
    
    DDLogInfo(@"[OwnTracksAppDelegate] OwnTracks starting %@/%@ %@",
              [NSBundle mainBundle].infoDictionary[@"CFBundleVersion"],
              [NSLocale currentLocale].localeIdentifier,
              launchOptions);
    
    [CoreData.sharedInstance sync:CoreData.sharedInstance.mainMOC];
    
    [self setShortcutItems];
    
#define TASK_IDENTIFIER @"updateSituation"
    self.bgTaskScheduler = [BGTaskScheduler sharedScheduler];
    BOOL success = [self.bgTaskScheduler
                    registerForTaskWithIdentifier:TASK_IDENTIFIER
                    usingQueue:nil
                    launchHandler:^(__kindof BGTask * _Nonnull task) {
        DDLogVerbose(@"[OwnTracksAppDelegate] launchHandler %@",
                     task.identifier);
        NSError *error;
        BGAppRefreshTaskRequest *bgAppRefreshTaskRequest =
        [[BGAppRefreshTaskRequest alloc] initWithIdentifier:TASK_IDENTIFIER];
        bgAppRefreshTaskRequest.earliestBeginDate = [NSDate dateWithTimeIntervalSinceNow:15 * 60];
        
        BOOL success = [self.bgTaskScheduler submitTaskRequest:bgAppRefreshTaskRequest error:&error];
        DDLogVerbose(@"[OwnTracksAppDelegate] submitTaskRequest %@ @ %@ %d, %@",
                     bgAppRefreshTaskRequest.identifier,
                     bgAppRefreshTaskRequest.earliestBeginDate,
                     success,
                     error);
        
        task.expirationHandler = ^{
            DDLogVerbose(@"[OwnTracksAppDelegate] bgTaskEspirationHandler");
            if (self.bgTask) {
                [self.bgTask setTaskCompletedWithSuccess:FALSE];
                self.bgTask = nil;
            }
        };
        [self performSelectorOnMainThread:@selector(doRefresh)
                               withObject:nil
                            waitUntilDone:TRUE];
        self.bgTask = task;
    }];
    DDLogVerbose(@"[OwnTracksAppDelegate] registerForTaskWithIdentifier %@ %d",
                 TASK_IDENTIFIER, success);
    
    NSError *error;
    BGAppRefreshTaskRequest *bgAppRefreshTaskRequest =
    [[BGAppRefreshTaskRequest alloc] initWithIdentifier:TASK_IDENTIFIER];
    bgAppRefreshTaskRequest.earliestBeginDate = [NSDate dateWithTimeIntervalSinceNow:15 * 60];
    success = [self.bgTaskScheduler submitTaskRequest:bgAppRefreshTaskRequest error:&error];
    DDLogVerbose(@"[OwnTracksAppDelegate] submitTaskRequest %@ @ %@ %d, %@",
                 bgAppRefreshTaskRequest.identifier,
                 bgAppRefreshTaskRequest.earliestBeginDate,
                 success,
                 error);
    
    self.backgroundTask = UIBackgroundTaskInvalid;
    
    UIBackgroundRefreshStatus status = [UIApplication sharedApplication].backgroundRefreshStatus;
    switch (status) {
        case UIBackgroundRefreshStatusAvailable:
            DDLogInfo(@"[OwnTracksAppDelegate] UIBackgroundRefreshStatusAvailable");
            break;
        case UIBackgroundRefreshStatusDenied:
            DDLogWarn(@"[OwnTracksAppDelegate] UIBackgroundRefreshStatusDenied");
#if !TARGET_OS_MACCATALYST
            self.backgroundFetchCheckMessage = NSLocalizedString(@"You disabled background fetch",
                                                                 @"You disabled background fetch");
#endif
            break;
        case UIBackgroundRefreshStatusRestricted:
            DDLogWarn(@"[OwnTracksAppDelegate] UIBackgroundRefreshStatusRestricted");
            self.backgroundFetchCheckMessage = NSLocalizedString(@"You cannot use background fetch",
                                                                 @"You cannot use background fetch");
            break;
    }
    
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    UNAuthorizationOptions options =
    UNAuthorizationOptionSound |
    UNAuthorizationOptionAlert |
    UNAuthorizationOptionBadge;
    [center requestAuthorizationWithOptions:options
                          completionHandler:^(BOOL granted, NSError * _Nullable error) {
        DDLogInfo(@"[OwnTracksAppDelegate] UNUserNotificationCenter requestAuthorizationWithOptions granted:%d error:%@", granted, error);
    }];
    center.delegate = self;
    
#if APNS
    [[UIApplication sharedApplication] registerForRemoteNotifications];
#endif
    
    return YES;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    DDLogVerbose(@"[OwnTracksAppDelegate] didFinishLaunchingWithOptions %@", launchOptions);
    
    self.connection = [[Connection alloc] init];
    self.connection.delegate = self;
    [self.connection start];
    
    [self connect];
    
    [[UIDevice currentDevice] setBatteryMonitoringEnabled:TRUE];
    
    LocationManager *locationManager = [LocationManager sharedInstance];
    locationManager.delegate = self;
    
    NSManagedObjectContext *moc = CoreData.sharedInstance.mainMOC;
    locationManager.monitoring = [Settings intForKey:@"monitoring_preference"
                                               inMOC:moc];
    locationManager.ranging = [Settings boolForKey:@"ranging_preference"
                                             inMOC:moc];
    locationManager.minDist = [Settings doubleForKey:@"mindist_preference"
                                               inMOC:moc];
    locationManager.minTime = [Settings doubleForKey:@"mintime_preference"
                                               inMOC:moc];
    [locationManager start];
    
    [FlicButtonServices.sharedInstance startService];
        
    [self setupLeftMenu];
    UIViewController* nav = [self initialViewController];
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.rootViewController = nav;

    [self.window makeKeyAndVisible];

    
    return YES;
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {
    if (@available(iOS 14.0, *)) {
        completionHandler(UNNotificationPresentationOptionBanner |
                          UNNotificationPresentationOptionSound);
    } else {
        completionHandler(UNNotificationPresentationOptionList |
                          UNNotificationPresentationOptionBanner |
                          UNNotificationPresentationOptionSound);
    }
    
}

#if APNS
- (void)application:(UIApplication *)application
didReceiveRemoteNotification:(NSDictionary *)userInfo
fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    DDLogInfo(@"[OwnTracksAppDelegate] didReceiveRemoteNotification starting");
    
    [self performSelectorOnMainThread:@selector(doRefresh)
                           withObject:nil
                        waitUntilDone:TRUE];
    DDLogInfo(@"[OwnTracksAppDelegate] didReceiveRemoteNotification finished");
    completionHandler(UIBackgroundFetchResultNewData);
}
#endif

- (void)applicationWillResignActive:(UIApplication *)application {
    DDLogInfo(@"[OwnTracksAppDelegate] applicationWillResignActive");
    //    #if !TARGET_OS_MACCATALYST
    //            if ([LocationManager sharedInstance].monitoring != LocationMonitoringMove) {
    //                [self.connection disconnect];
    //            }
    //    #else
    //            [self.connection disconnect];
    //    #endif
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    DDLogInfo(@"[OwnTracksAppDelegate] applicationDidEnterBackground");
#if !TARGET_OS_MACCATALYST
    [self background];
#if !TARGET_OS_MACCATALYST
    if ([LocationManager sharedInstance].monitoring != LocationMonitoringMove) {
        [self.connection disconnect];
    }
#else
    [self.connection disconnect];
#endif
#endif
}

- (void)applicationWillTerminate:(UIApplication *)application {
    DDLogInfo(@"[OwnTracksAppDelegate] applicationWillTerminate");
    [self background];
    [self.connection disconnect];
    
}

-(BOOL)application:(UIApplication *)app
           openURL:(NSURL *)url
           options:(NSDictionary<NSString *,id> *)options {
    DDLogInfo(@"[OwnTracksAppDelegate] openURL %@ options %@", url, options);
    
    if (url) {
        DDLogVerbose(@"[OwnTracksAppDelegate] URL scheme %@", url.scheme);
        
        if ([url.scheme isEqualToString:@"owntracks"]) {
            DDLogVerbose(@"[OwnTracksAppDelegate] URL path %@ query %@", url.path, url.query);
            
            NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:TRUE];
            NSArray<NSURLQueryItem *> *items = [components queryItems];
            NSMutableDictionary *queryStrings = [[NSMutableDictionary alloc] init];
            for (NSURLQueryItem *item in items) {
                queryStrings[item.name] = item.value;
            }
            
            if ([url.path isEqualToString:@"/beacon"]) {
                NSString *rid = queryStrings[@"rid"];
                NSString *name = queryStrings[@"name"];
                NSString *uuid = queryStrings[@"uuid"];
                int major = [queryStrings[@"major"] intValue];
                int minor = [queryStrings[@"minor"] intValue];
                
                if (!rid) {
                    rid = Region.newRid;
                }
                
                NSString *desc = [NSString stringWithFormat:@"%@:%@%@%@",
                                  name,
                                  uuid,
                                  major ? [NSString stringWithFormat:@":%d", major] : @"",
                                  minor ? [NSString stringWithFormat:@":%d", minor] : @""
                ];
                
                [Settings waypointsFromDictionary:
                 @{@"_type":@"waypoints",
                   @"waypoints":@[@{@"_type":@"waypoint",
                                    @"rid":rid,
                                    @"desc":desc,
                                    @"tst":@((int)round(([NSDate date].timeIntervalSince1970))),
                                    @"lat":@([LocationManager sharedInstance].location.coordinate.latitude),
                                    @"lon":@([LocationManager sharedInstance].location.coordinate.longitude),
                                    @"rad":@(-1)
                   }]
                 } inMOC:CoreData.sharedInstance.mainMOC];
                [CoreData.sharedInstance sync:CoreData.sharedInstance.mainMOC];
                self.processingMessage = NSLocalizedString(@"Beacon QR successfully processed",
                                                           @"Display after processing beacon QR code");
                DDLogInfo(@"[OwnTracksAppDelegate] openURL ok %@", self.processingMessage);
                return TRUE;
            } else if ([url.path isEqualToString:@"/config"]) {
                NSString *urlString = queryStrings[@"url"];
                NSString *base64String = queryStrings[@"inline"];
                if (urlString) {
                    NSURL *urlFromString = [NSURL URLWithString:urlString];
                    return [self processNSURL:urlFromString];
                } else if (base64String) {
                    NSData *jsonData = [[NSData alloc] initWithBase64EncodedString:base64String options:0];
                    if (jsonData) {
                        NSDictionary *dict = nil;
                        id json = [[Validation sharedInstance] validateMessageData:jsonData];
                        if (json &&
                            [json isKindOfClass:[NSDictionary class]]) {
                            dict = json;
                        }
                        if (dict) {
                            [self performSelectorOnMainThread:@selector(terminateSession)
                                                   withObject:nil
                                                waitUntilDone:TRUE];
                            [self performSelectorOnMainThread:@selector(configFromDictionary:)
                                                   withObject:dict
                                                waitUntilDone:TRUE];
                            self.configLoad = [NSDate date];
                            [self performSelectorOnMainThread:@selector(reconnect)
                                                   withObject:nil
                                                waitUntilDone:TRUE];
                            
                            self.processingMessage = NSLocalizedString(@"Inline Configuration successfully processed",
                                                                       @"Display after processing inline config");
                            DDLogInfo(@"[OwnTracksAppDelegate] openURL ok %@", self.processingMessage);
                            return TRUE;
                        } else {
                            self.processingMessage = NSLocalizedString(@"Inline Configuration incorrect",
                                                                       @"Display for incorrect inline config");
                            DDLogInfo(@"[OwnTracksAppDelegate] openURL problem %@", self.processingMessage);
                            return FALSE;
                        }
                    } else {
                        self.processingMessage = NSLocalizedString(@"Inline Configuration incorrectly encoded",
                                                                   @"Display for incorrectly encoded inline config");
                        DDLogInfo(@"[OwnTracksAppDelegate] openURL problem %@", self.processingMessage);
                        return FALSE;
                    }
                }
                self.processingMessage = NSLocalizedString(@"Inline Configuration missing parameters",
                                                           @"Display for config without parameters");
                DDLogInfo(@"[OwnTracksAppDelegate] openURL problem %@", self.processingMessage);
                return FALSE;
            } else {
                self.processingMessage = NSLocalizedString(@"unknown url path",
                                                           @"Display for unknown url path");
                DDLogInfo(@"[OwnTracksAppDelegate] openURL problem %@", self.processingMessage);
                return FALSE;
            }
        } else if ([url.scheme isEqualToString:@"file"]) {
            return [self processFile:url];
        } else if ([url.scheme isEqualToString:@"http"] ||
                   [url.scheme isEqualToString:@"https"]) {
            return [self processNSURL:url];
        } else {
            self.processingMessage = [NSString stringWithFormat:@"%@ %@",
                                      NSLocalizedString(@"unknown scheme in url",
                                                        @"Display after entering an unknown scheme in url"),
                                      url.scheme];
            DDLogInfo(@"[OwnTracksAppDelegate] openURL problem %@", self.processingMessage);
            return FALSE;
        }
    }
    self.processingMessage = NSLocalizedString(@"no url specified",
                                               @"Display after trying to process a file");
    DDLogInfo(@"[OwnTracksAppDelegate] openURL problem %@", self.processingMessage);
    return FALSE;
}

- (BOOL)processNSURL:(NSURL *)url {
    DDLogInfo(@"[OwnTracksAppDelegate] processNSURL %@", url);
    
    self.processingMessage = nil;
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    NSURLSessionDataTask *dataTask =
    [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:
     ^(NSData *data, NSURLResponse *response, NSError *error) {
        
        DDLogVerbose(@"[OwnTracksAppDelegate] dataTaskWithRequest %@ %@ %@", data, response, error);
        if (!error) {
            
            if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                DDLogInfo(@"[OwnTracksAppDelegate] NSHTTPURLResponse %@", httpResponse);
                if (httpResponse.statusCode >= 200 && httpResponse.statusCode <= 299) {
                    DDLogInfo(@"[OwnTracksAppDelegate] URL pathExtension %@", url.pathExtension);
                    NSError *error;
                    NSString *extension = url.pathExtension;
                    if ([extension isEqualToString:@"otrc"] || [extension isEqualToString:@"mqtc"]) {
                        NSDictionary *dict = nil;
                        id json = [[Validation sharedInstance] validateMessageData:data];
                        if (json &&
                            [json isKindOfClass:[NSDictionary class]]) {
                            dict = json;
                        }
                        if (dict) {
                            [self performSelectorOnMainThread:@selector(terminateSession)
                                                   withObject:nil
                                                waitUntilDone:TRUE];
                            [self performSelectorOnMainThread:@selector(configFromDictionary:)
                                                   withObject:dict
                                                waitUntilDone:TRUE];
                            self.configLoad = [NSDate date];
                            [self performSelectorOnMainThread:@selector(reconnect)
                                                   withObject:nil
                                                waitUntilDone:TRUE];
                        }
                    } else if ([extension isEqualToString:@"otrw"] || [extension isEqualToString:@"mqtw"]) {
                        NSDictionary *dict = nil;
                        id json = [[Validation sharedInstance] validateMessageData:data];
                        if (json &&
                            [json isKindOfClass:[NSDictionary class]]) {
                            dict = json;
                        }
                        if (dict) {
                            [self performSelectorOnMainThread:@selector(waypointsFromDictionary:)
                                                   withObject:dict
                                                waitUntilDone:TRUE];
                        }
                    } else if ([extension isEqualToString:@"otrp"] || [extension isEqualToString:@"otre"]) {
                        NSURL *directoryURL = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory
                                                                                     inDomain:NSUserDomainMask
                                                                            appropriateForURL:nil
                                                                                       create:YES
                                                                                        error:&error];
                        NSString *fileName = url.lastPathComponent;
                        NSURL *fileURL = [directoryURL URLByAppendingPathComponent:fileName];
                        [[NSFileManager defaultManager] createFileAtPath:fileURL.path
                                                                contents:data
                                                              attributes:nil];
                    } else {
                        [self.navigationController alert:@"processNSURL"
                                                 message:
                         [NSString stringWithFormat:@"OOPS %@ %@",
                          [NSError errorWithDomain:@"OwnTracks"
                                              code:2
                                          userInfo:@{@"extension":extension ? extension : @"(null)"}],
                          url]];
                    }
                } else {
                    [self.navigationController alert:@"processNSURL"
                                             message:
                         [NSString stringWithFormat:@"httpResponse.statusCode %ld %@",
                          (long)httpResponse.statusCode,
                          url]
                    ];
                }
            } else {
                [self.navigationController alert:@"processNSURL"
                                         message:
                     [NSString stringWithFormat:@"response %@ %@",
                      response,
                      url]
                ];
            }
        } else {
            [self.navigationController alert:@"processNSURL"
                                     message:
                 [NSString stringWithFormat:@"dataTaskWithRequest %@ %@",
                  error,
                  url]
            ];
        }
    }];
    [dataTask resume];
    return TRUE;
}

- (void)configFromDictionary:(NSDictionary *)json {
    NSError *error = [Settings fromDictionary:json inMOC:CoreData.sharedInstance.mainMOC];
    [CoreData.sharedInstance sync:CoreData.sharedInstance.mainMOC];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"reload" object:nil];

    if (error) {
        [self.navigationController alert:@"processNSURL"
                                 message:
             [NSString stringWithFormat:@"configFromDictionary %@ %@",
              error,
              json]
        ];
    }
}

- (void)waypointsFromDictionary:(NSDictionary *)json {
    NSError *error = [Settings waypointsFromDictionary:json inMOC:CoreData.sharedInstance.mainMOC];
    [CoreData.sharedInstance sync:CoreData.sharedInstance.mainMOC];
    if (error) {
        [self.navigationController alert:@"processNSURL"
                                 message:
             [NSString stringWithFormat:@"waypointsFromDictionary %@ %@",
              error,
              json]
        ];
    }
}

- (BOOL)processFile:(NSURL *)url {
    DDLogInfo(@"[OwnTracksAppDelegate] processFile %@", url);
    NSInputStream *input = [NSInputStream inputStreamWithURL:url];
    if (input.streamError) {
        self.processingMessage = [NSString stringWithFormat:@"inputStreamWithURL %@ %@",
                                  input.streamError,
                                  url];
        DDLogInfo(@"[OwnTracksAppDelegate] processFile problem %@", self.processingMessage);
        return FALSE;
    }
    [input open];
    if (input.streamError) {
        self.processingMessage = [NSString stringWithFormat:@"%@ %@ %@",
                                  NSLocalizedString(@"file open error",
                                                    @"Display after trying to open a file"),
                                  input.streamError,
                                  url];
        DDLogInfo(@"[OwnTracksAppDelegate] processFile problem %@", self.processingMessage);
        return FALSE;
    }
    
    DDLogInfo(@"[OwnTracksAppDelegate] URL pathExtension %@", url.pathExtension);
    
    NSError *error;
    NSString *extension = url.pathExtension;
    if ([extension isEqualToString:@"otrc"] || [extension isEqualToString:@"mqtc"]) {
        [self terminateSession];
        error = [Settings fromStream:input inMOC:CoreData.sharedInstance.mainMOC];
        [CoreData.sharedInstance sync:CoreData.sharedInstance.mainMOC];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"reload" object:nil];
        self.configLoad = [NSDate date];
        [self reconnect];
    } else if ([extension isEqualToString:@"otrw"] || [extension isEqualToString:@"mqtw"]) {
        error = [Settings waypointsFromStream:input inMOC:CoreData.sharedInstance.mainMOC];
        [CoreData.sharedInstance sync:CoreData.sharedInstance.mainMOC];
    } else if ([extension isEqualToString:@"otrp"] || [extension isEqualToString:@"otre"]) {
        NSURL *directoryURL = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory
                                                                     inDomain:NSUserDomainMask
                                                            appropriateForURL:nil
                                                                       create:YES
                                                                        error:&error];
        NSString *fileName = url.lastPathComponent;
        NSURL *fileURL = [directoryURL URLByAppendingPathComponent:fileName];
        [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
        [[NSFileManager defaultManager] copyItemAtURL:url toURL:fileURL error:nil];
    } else {
        error = [NSError errorWithDomain:@"OwnTracks"
                                    code:2
                                userInfo:@{@"extension":extension ? extension : @"(null)"}];
    }
    
    [input close];
    
    // MAC CATALYST opens files in place
#if !TARGET_OS_MACCATALYST
    [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
#endif
    
    if (error) {
        self.processingMessage = [NSString stringWithFormat:@"%@ %@: %@ %@",
                                  NSLocalizedString(@"Error processing file",
                                                    @"Display when file processing fails"),
                                  url.lastPathComponent,
                                  error.localizedDescription,
                                  error.userInfo];
        DDLogInfo(@"[OwnTracksAppDelegate] processFile problem %@", self.processingMessage);
        return FALSE;
    }
    self.processingMessage = [NSString stringWithFormat:@"%@ %@ %@",
                              NSLocalizedString(@"File",
                                                @"Display when file processing succeeds (filename follows)"),
                              url.lastPathComponent,
                              NSLocalizedString(@"successfully processed",
                                                @"Display when file processing succeeds")];
    DDLogInfo(@"[OwnTracksAppDelegate] processFile ok %@", self.processingMessage);
    return TRUE;
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    DDLogInfo(@"[OwnTracksAppDelegate] applicationDidBecomeActive");
    
    [self.connection connectToLast];
    
    if (self.disconnectTimer && self.disconnectTimer.isValid) {
        DDLogVerbose(@"[OwnTracksAppDelegate] disconnectTimer invalidate %@",
                     self.disconnectTimer.fireDate);
        [self.disconnectTimer invalidate];
    }
    
    if (self.backgroundFetchCheckMessage) {
        [self.navigationController alert:@"Background Fetch"
                                 message:self.backgroundFetchCheckMessage];
        self.backgroundFetchCheckMessage = nil;
    }
    
    if (self.processingMessage) {
        [self.navigationController alert:@"openURL"
                                 message:self.processingMessage];
        self.processingMessage = nil;
        [self reconnect];
    }
    
    if (![Settings validIdsInMOC:CoreData.sharedInstance.mainMOC]) {
        NSString *message = NSLocalizedString(@"To publish your location userID and deviceID must be set",
                                              @"Warning displayed if necessary settings are missing");
        
        [self.navigationController alert:@"Settings"
                                 message:message];
    }
}

- (void)doRefresh {
    DDLogInfo(@"[OwnTracksAppDelegate] doRefresh");
    self.inRefresh = TRUE;
    [self background];
    
    [[LocationManager sharedInstance] wakeup];
    [self.connection connectToLast];
}

- (void)background {
    NSTimeInterval backgroundTimeRemaining = [UIApplication sharedApplication].backgroundTimeRemaining;
    DDLogVerbose(@"[OwnTracksAppDelegate] background backgroundTimeRemaining: %@",
                 backgroundTimeRemaining > 24 * 3600 ? @"∞": @(floor(backgroundTimeRemaining)).stringValue);
    
    [self startBackgroundTimer];
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground &&
        self.backgroundTask == UIBackgroundTaskInvalid) {
        self.backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
            DDLogVerbose(@"[OwnTracksAppDelegate] BackgroundTaskExpirationHandler");
            if (self.backgroundTask) {
                [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTask];
                self.backgroundTask = UIBackgroundTaskInvalid;
            }
        }];
        DDLogVerbose(@"[OwnTracksAppDelegate] beginBackgroundTaskWithExpirationHandler %lu",
                     (unsigned long)self.backgroundTask);
    }
}

- (void)startBackgroundTimer {
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground &&
        [LocationManager sharedInstance].monitoring != LocationMonitoringMove) {
        if (self.disconnectTimer && self.disconnectTimer.isValid) {
            DDLogVerbose(@"[OwnTracksAppDelegate] disconnectTimer.isValid %@",
                         self.disconnectTimer.fireDate);
        } else {
            self.disconnectTimer = [NSTimer timerWithTimeInterval:BACKGROUND_DISCONNECT_AFTER
                                                           target:self
                                                         selector:@selector(disconnectInBackground)
                                                         userInfo:Nil
                                                          repeats:FALSE];
            NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
            [runLoop addTimer:self.disconnectTimer forMode:NSDefaultRunLoopMode];
            DDLogVerbose(@"[OwnTracksAppDelegate] disconnectTimer %@",
                         self.disconnectTimer.fireDate);
            
            if (self.holdTimer) {
                if (self.holdTimer.isValid) {
                    [self.holdTimer invalidate];
                }
                self.holdTimer = nil;
            }
            self.holdTimer = [NSTimer scheduledTimerWithTimeInterval:BACKGROUND_HOLD_FOR
                                                             repeats:FALSE
                                                               block:^(NSTimer * _Nonnull timer) {
                DDLogVerbose(@"[OwnTracksAppDelegate] holdTimer");
                if (self.bgTimer) {
                    if (self.bgTimer.isValid) {
                        [self.bgTimer invalidate];
                    }
                    self.bgTimer = nil;
                }
                self.bgTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                               repeats:TRUE
                                                                 block:^(NSTimer * _Nonnull timer) {
                    DDLogVerbose(@"[OwnTracksAppDelegate] bgTimer %@ %@",
                                 self.connectionState,
                                 self.connectionBuffered);
                    if (!self.connectionBuffered || !self.connectionBuffered.intValue) {
                        if (self.connectionState.intValue == state_connected) {
                            [self disconnectInBackground];
                        }
                    }
                }];
            }];
        }
    }
}

- (void)disconnectInBackground {
    DDLogInfo(@"[OwnTracksAppDelegate] disconnectInBackground");
    [self.connection disconnect];
}

- (void)application:(UIApplication *)application
performActionForShortcutItem:(UIApplicationShortcutItem *)shortcutItem completionHandler:(void (^)(BOOL))completionHandler {
    DDLogInfo(@"[OwnTracksAppDelegate] performActionForShortcutItem %@", shortcutItem.type);
    if ([shortcutItem.type isEqualToString:@"org.mqttitude.MQTTitude.movemode"]) {
        LocationMonitoring monitoring = LocationMonitoringMove;
        [LocationManager sharedInstance].monitoring = monitoring;
        [[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:@"downgraded"];
        NSManagedObjectContext *moc = CoreData.sharedInstance.mainMOC;
        [Settings setInt:(int)[LocationManager sharedInstance].monitoring
                  forKey:@"monitoring_preference" inMOC:moc];
        [CoreData.sharedInstance sync:moc];
        completionHandler(TRUE);
    } else if ([shortcutItem.type isEqualToString:@"org.mqttitude.MQTTitude.significantmode"]) {
        LocationMonitoring monitoring = LocationMonitoringSignificant;
        [LocationManager sharedInstance].monitoring = monitoring;
        [[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:@"downgraded"];
        NSManagedObjectContext *moc = CoreData.sharedInstance.mainMOC;
        [Settings setInt:(int)[LocationManager sharedInstance].monitoring
                  forKey:@"monitoring_preference" inMOC:moc];
        [CoreData.sharedInstance sync:moc];
        completionHandler(TRUE);
    } else if ([shortcutItem.type isEqualToString:@"org.mqttitude.MQTTitude.manualmode"]) {
        LocationMonitoring monitoring = LocationMonitoringManual;
        [LocationManager sharedInstance].monitoring = monitoring;
        [[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:@"downgraded"];
        NSManagedObjectContext *moc = CoreData.sharedInstance.mainMOC;
        [Settings setInt:(int)[LocationManager sharedInstance].monitoring
                  forKey:@"monitoring_preference" inMOC:moc];
        [CoreData.sharedInstance sync:moc];
        completionHandler(TRUE);
    } else if ([shortcutItem.type isEqualToString:@"org.mqttitude.MQTTitude.quietmode"]) {
        LocationMonitoring monitoring = LocationMonitoringQuiet;
        [LocationManager sharedInstance].monitoring = monitoring;
        [[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:@"downgraded"];
        NSManagedObjectContext *moc = CoreData.sharedInstance.mainMOC;
        [Settings setInt:(int)[LocationManager sharedInstance].monitoring
                  forKey:@"monitoring_preference" inMOC:moc];
        [CoreData.sharedInstance sync:moc];
        completionHandler(TRUE);
        
    } else {
        completionHandler(FALSE);
    }
}

/*
 *
 * LocationManagerDelegate
 *
 */

- (void)newLocation:(CLLocation *)location {
    [self background];
    if (self.inRefresh) {
        self.inRefresh = FALSE;
        [self publishLocation:location trigger:@"p" withPOI:nil];
    } else {
        [self publishLocation:location trigger:nil withPOI:nil];
    }
}

- (void)timerLocation:(CLLocation *)location {
    [self background];
    [self publishLocation:location trigger:@"t" withPOI:nil];
}

- (void)visitLocation:(CLLocation *)location {
    [self background];
    [self publishLocation:location trigger:@"v" withPOI:nil];
}

- (void)regionEvent:(CLRegion *)region enter:(BOOL)enter {
    [self background];
    NSManagedObjectContext *moc = CoreData.sharedInstance.mainMOC;
    if ([LocationManager sharedInstance].monitoring != LocationMonitoringQuiet &&
        [Settings validIdsInMOC:moc]) {
        
        if (!region.isFollow) {
            NSArray <NSString *> *components = [region.identifier componentsSeparatedByString:@"|"];
            NSString *notificationMessage = [NSString stringWithFormat:@"%@ %@",
                                             (enter ?
                                              NSLocalizedString(@"Entering",
                                                                @"Display when entering region (region name follows)"):
                                              NSLocalizedString(@"Leaving",
                                                                @"Display when leaving region (region name follows)")
                                              ),
                                             components[0]];
            
            UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
            content.body = notificationMessage;
            content.sound = [UNNotificationSound defaultSound];
            UNTimeIntervalNotificationTrigger* trigger = [UNTimeIntervalNotificationTrigger
                                                          triggerWithTimeInterval:1.0
                                                          repeats:NO];
            NSString *notificationIdentifier = [NSString stringWithFormat:@"region%f",
                                                [NSDate date].timeIntervalSince1970];
            
            UNNotificationRequest* request = [UNNotificationRequest requestWithIdentifier:notificationIdentifier
                                                                                  content:content
                                                                                  trigger:trigger];
            UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
            [center addNotificationRequest:request withCompletionHandler:nil];
            
            [History historyInGroup:NSLocalizedString(@"Region",
                                                      @"Header of an alert message regarding circular region")
                           withText:notificationMessage
                                 at:nil
                              inMOC:moc
                            maximum:[Settings theMaximumHistoryInMOC:moc]];
            [CoreData.sharedInstance sync:moc];
            
            Friend *myself = [Friend existsFriendWithTopic:[Settings theGeneralTopicInMOC:moc]
                                    inManagedObjectContext:moc];
            
            CLLocation *location = [LocationManager sharedInstance].location;
            
            NSMutableDictionary *json = [[NSMutableDictionary alloc] init];
            json[@"_type"] = @"transition";
            
            json[@"lat"] = [NSNumber doubleValueWithSixDecimals:location.coordinate.latitude];
            
            json[@"lon"] = [NSNumber doubleValueWithSixDecimals:location.coordinate.longitude];
            
            json[@"tst"] = [NSNumber doubleValueWithZeroDecimals:location.timestamp.timeIntervalSince1970];
            
            if (location.horizontalAccuracy >= 0.0) {
                json[@"acc"] = [NSNumber doubleValueWithZeroDecimals:location.horizontalAccuracy];
            }
            json[@"tid"] = myself.effectiveTid;
            json[@"event"] = enter ? @"enter" : @"leave";
            json[@"t"] =  [region isKindOfClass:[CLBeaconRegion class]] ? @"b" : @"c";
            
            if (fabs(location.timestamp.timeIntervalSince1970 -
                     [NSDate date].timeIntervalSince1970) > 1.0) {
                json[@"created_at"] = [NSNumber doubleValueWithZeroDecimals:[NSDate date].timeIntervalSince1970];
            }
            
            for (Region *anyRegion in myself.hasRegions) {
                if ([region.identifier isEqualToString:anyRegion.CLregion.identifier]) {
                    anyRegion.name = anyRegion.name;
                    json[@"desc"] = components[0];
                    json[@"wtst"] = [NSNumber doubleValueWithZeroDecimals:anyRegion.tst.timeIntervalSince1970];
                    json[@"rid"] = anyRegion.andFillRid;
                    
                    [self.connection sendData:[self jsonToData:json]
                                        topic:[[Settings theGeneralTopicInMOC:moc] stringByAppendingString:@"/event"]
                                   topicAlias:@(2)
                                          qos:[Settings intForKey:@"qos_preference"
                                                            inMOC:moc]
                                       retain:NO];
                    if ([region isKindOfClass:[CLBeaconRegion class]]) {
                        if ((anyRegion.radius).doubleValue < 0) {
                            anyRegion.lat = @(location.coordinate.latitude);
                            anyRegion.lon = @(location.coordinate.longitude);
                            [self sendRegion:anyRegion];
                        }
                    }
                    
                    NSArray <NSString *> *components = [region.identifier componentsSeparatedByString:@"|"];
                    if (components.count == 3) {
                        LocationMonitoring newMonitoring;
                        if (enter) {
                            newMonitoring = components[1].integerValue;
                        } else {
                            newMonitoring = components[2].integerValue;
                        }
                        LocationManager.sharedInstance.monitoring = newMonitoring;
                        [[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:@"downgraded"];
                        [Settings setInt:(int)[LocationManager sharedInstance].monitoring
                                  forKey:@"monitoring_preference" inMOC:moc];
                        [CoreData.sharedInstance sync:moc];
                        [self background];
                    }
                }
            }
            
            if ([region isKindOfClass:[CLBeaconRegion class]]) {
                [self publishLocation:[LocationManager sharedInstance].location trigger:@"b" withPOI:nil];
            } else {
                [self publishLocation:[LocationManager sharedInstance].location trigger:@"c" withPOI:nil];
            }
        } else {
            if ([LocationManager sharedInstance].monitoring != LocationMonitoringMove) {
                [self publishLocation:[LocationManager sharedInstance].location trigger:@"C" withPOI:nil];
            }
        }
    }
}

- (void)regionState:(CLRegion *)region inside:(BOOL)inside {
    DDLogVerbose(@"[OwnTracksAppDelegate] regionState %@ i:%d", region.identifier, inside);
    Friend *myself = [Friend existsFriendWithTopic:[Settings theGeneralTopicInMOC:CoreData.sharedInstance.mainMOC]
                            inManagedObjectContext:CoreData.sharedInstance.mainMOC];
    
    for (Region *anyRegion in myself.hasRegions) {
        if ([region.identifier isEqualToString:anyRegion.CLregion.identifier]) {
            anyRegion.name = anyRegion.name;
        }
    }
}

-(void)beaconInRange:(CLBeacon *)beacon
    beaconConstraint:(CLBeaconIdentityConstraint *)beaconConstraint {
    [self background];
    if ([Settings validIdsInMOC:CoreData.sharedInstance.mainMOC]) {
        Friend *myself = [Friend existsFriendWithTopic:[Settings theGeneralTopicInMOC:CoreData.sharedInstance.mainMOC]
                                inManagedObjectContext:CoreData.sharedInstance.mainMOC];
        
        Region *myRegion;
        for (Region *anyRegion in myself.hasRegions) {
            if ([beaconConstraint.UUID.UUIDString isEqualToString:anyRegion.uuid]) {
                if ((!anyRegion.major &&
                     !beaconConstraint.major
                     ) ||
                    (anyRegion.major &&
                     beaconConstraint.major &&
                     anyRegion.major.intValue == beaconConstraint.major.intValue &&
                     ((!anyRegion.minor &&
                       !beaconConstraint.minor
                       ) ||
                      (anyRegion.minor &&
                       beaconConstraint.minor &&
                       anyRegion.minor.intValue == beaconConstraint.minor.intValue
                       )
                      )
                     )
                    ) {
                    myRegion = anyRegion;
                    break;
                }
            }
        }
        
        NSMutableDictionary *json = [[NSMutableDictionary alloc] init];
        json[@"_type"] = @"beacon";
        json[@"tid"] = myself.effectiveTid;
        json[@"tst"] = [NSNumber doubleValueWithZeroDecimals:[LocationManager sharedInstance].location.timestamp.timeIntervalSince1970];
        
        json[@"uuid"] = (beacon.UUID).UUIDString;
        json[@"major"] = beacon.major;
        json[@"minor"] = beacon.minor;
        json[@"prox"] = @(beacon.proximity);
        json[@"acc"] = [NSNumber doubleValueWithZeroDecimals:beacon.accuracy];
        json[@"rssi"] = @(beacon.rssi);
        if (myRegion) {
            json[@"desc"] = myRegion.name;
        }
        [self.connection sendData:[self jsonToData:json]
                            topic:[[Settings theGeneralTopicInMOC:CoreData.sharedInstance.mainMOC] stringByAppendingString:@"/beacon"]
                       topicAlias:@(3)
                              qos:[Settings intForKey:@"qos_preference"
                                                inMOC:CoreData.sharedInstance.mainMOC]
                           retain:NO];
    }
}

#pragma ConnectionDelegate

- (void)showState:(Connection *)connection
            state:(NSInteger)state {
    DDLogVerbose(@"[OwnTracksAppDelegate] showState: %ld", (long)state);
    
    self.connectionState = @(state);
    [self performSelectorOnMainThread:@selector(checkState:) withObject:@(state) waitUntilDone:NO];
}

- (void)checkState:(NSNumber *)state {
    /**
     ** This is a hack to ensure the connection gets gracefully closed at the server
     **
     ** If the background task is ended, occasionally the disconnect message is not received well before the server senses the tcp disconnect
     **/
    
    NSTimeInterval backgroundTimeRemaining = [UIApplication sharedApplication].backgroundTimeRemaining;
    DDLogVerbose(@"[OwnTracksAppDelegate] checkState: %@, backgroundTimeRemaining: %@",
                 state,
                 backgroundTimeRemaining > 24 * 3600 ? @"∞": @(floor(backgroundTimeRemaining)).stringValue);
    
    if (state.intValue == state_starting) {
        if (self.backgroundTask) {
            if (self.bgTimer) {
                if (self.bgTimer.isValid) {
                    [self.bgTimer invalidate];
                }
                self.bgTimer = nil;
            }
            if (self.holdTimer) {
                if (self.holdTimer.isValid) {
                    [self.holdTimer invalidate];
                }
                self.holdTimer = nil;
            }
            if (self.disconnectTimer) {
                if (self.disconnectTimer.isValid) {
                    [self.disconnectTimer invalidate];
                }
                self.disconnectTimer = nil;
            }
            
            DDLogVerbose(@"[OwnTracksAppDelegate] endBackGroundTask %lu",
                         (unsigned long)self.backgroundTask);
            [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTask];
            self.backgroundTask = UIBackgroundTaskInvalid;
        }
        if (self.bgTask) {
            [self.bgTask setTaskCompletedWithSuccess:TRUE];
            self.bgTask = nil;
        }
    }
}

- (BOOL)handleMessage:(Connection *)connection
                 data:(NSData *)data
              onTopic:(NSString *)topic
             retained:(BOOL)retained {
    DDLogVerbose(@"[OwnTracksAppDelegate] handleMessage");
    
    [CoreData.sharedInstance.queuedMOC performBlock:^{
        (void)[[OwnTracking sharedInstance] processMessage:topic
                                                      data:data
                                                  retained:retained
                                                   context:CoreData.sharedInstance.queuedMOC];
        NSArray *baseComponents = [[Settings theGeneralTopicInMOC:CoreData.sharedInstance.queuedMOC] componentsSeparatedByString:@"/"];
        NSArray *topicComponents = [topic componentsSeparatedByString:@"/"];
        
        NSString *device = @"";
        BOOL ownDevice = true;
        
        for (int i = 0; i < baseComponents.count; i++) {
            if (i > 0) {
                device = [device stringByAppendingString:@"/"];
            }
            if (i < topicComponents.count) {
                device = [device stringByAppendingString:topicComponents[i]];
                if (![baseComponents[i] isEqualToString:topicComponents [i]]) {
                    ownDevice = false;
                }
            } else {
                ownDevice = false;
            }
        }
        
        DDLogVerbose(@"[OwnTracksAppDelegate] device %@ owndevice %d", device, ownDevice);
        
        if (ownDevice) {
            
            NSDictionary *dictionary = nil;
            id json = [[Validation sharedInstance] validateMessageData:data];
            if (json && [json isKindOfClass:[NSDictionary class]]) {
                dictionary = json;
            }
            
            if (dictionary) {
                NSString *type = dictionary[@"_type"];
                if (type && [type isKindOfClass:[NSString class]]) {
                    if ([type isEqualToString:@"cmd"]) {
                        if ([Settings boolForKey:@"cmd_preference"
                                           inMOC:CoreData.sharedInstance.queuedMOC]) {
                            NSString *action = dictionary[@"action"];
                            if (action && [action isKindOfClass:[NSString class]]) {
                                if ([action isEqualToString:@"dump"]) {
                                    [self dump];
                                    
                                } else if ([action isEqualToString:@"status"]) {
                                    [self status];

                                } else if ([action isEqualToString:@"reportLocation"]) {
                                    if ([LocationManager sharedInstance].monitoring == LocationMonitoringSignificant ||
                                        [LocationManager sharedInstance].monitoring == LocationMonitoringMove ||
                                        [Settings boolForKey:@"allowremotelocation_preference"
                                                       inMOC:CoreData.sharedInstance.queuedMOC]) {
                                        [self performSelectorOnMainThread:@selector(reportLocation)
                                                               withObject:nil
                                                            waitUntilDone:NO];
                                    }
                                    
                                } else if ([action isEqualToString:@"reportSteps"]) {
                                    NSNumber *from = dictionary[@"from"];
                                    NSNumber *to = dictionary[@"to"];
                                    if ((!from || [from isKindOfClass:[NSNumber class]]) &&
                                        (!to || [to isKindOfClass:[NSNumber class]])) {
                                        [self stepsFrom:from to:to];
                                    } else {
                                        DDLogWarn(@"[OwnTracksAppDelegate] from and to must be numbers");
                                    }
                                    
                                } else if ([action isEqualToString:@"waypoints"]) {
                                    [self performSelectorOnMainThread:@selector(waypoints)
                                                           withObject:nil
                                                        waitUntilDone:NO];
                                    
                                } else if ([action isEqualToString:@"action"]) {
                                    [self performSelectorOnMainThread:@selector(performAction:)
                                                           withObject:dictionary
                                                        waitUntilDone:NO];
                                    
                                } else if ([action isEqualToString:@"setWaypoints"]) {
                                    [self performSelectorOnMainThread:@selector(performSetWaypoints:)
                                                           withObject:dictionary
                                                        waitUntilDone:NO];
                                    
                                } else if ([action isEqualToString:@"clearWaypoints"]) {
                                    [self performSelectorOnMainThread:@selector(performClearWaypoints:)
                                                           withObject:dictionary
                                                        waitUntilDone:NO];
                                    
                                } else if ([action isEqualToString:@"setConfiguration"]) {
                                    [self performSelectorOnMainThread:@selector(performSetConfiguration:)
                                                           withObject:dictionary
                                                        waitUntilDone:NO];
                                    
                                } else if ([action isEqualToString:@"response"]) {
                                    [self performSelectorOnMainThread:@selector(performResponse:)
                                                           withObject:dictionary
                                                        waitUntilDone:NO];
                                    
                                } else {
                                    DDLogWarn(@"[OwnTracksAppDelegate] unknown action %@", action);
                                }
                            } else {
                                DDLogWarn(@"[OwnTracksAppDelegate] no action in JSON");
                            }
                        } else {
                            DDLogWarn(@"[OwnTracksAppDelegate] remote cmd not allowed");
                        }
                    } else {
                        DDLogVerbose(@"[OwnTracksAppDelegate] unhandled _type (%@) in JSON", type);
                    }
                } else {
                    DDLogWarn(@"[OwnTracksAppDelegate] no _type in JSON");
                }
            } else {
                DDLogWarn(@"[OwnTracksAppDelegate] JSON is not an object");
            }
        }
        [CoreData.sharedInstance sync:CoreData.sharedInstance.queuedMOC];
    }];
    
    return true;
}

- (void)messageDelivered:(Connection *)connection msgID:(UInt16)msgID {
    // noop
}

- (void)totalBuffered:(Connection *)connection count:(NSUInteger)count {
    self.connectionBuffered = @(count);
    [self performSelectorOnMainThread:@selector(updateUI) withObject:nil waitUntilDone:NO];
}

- (void)updateUI {
    [UIApplication sharedApplication].applicationIconBadgeNumber = self.connectionBuffered.intValue;
}

- (void)dump {
    NSMutableDictionary *json = [[NSMutableDictionary alloc] init];
    json[@"_type"] = @"dump";
    json[@"configuration"] = [Settings toDictionaryInMOC:CoreData.sharedInstance.mainMOC];
    [self.connection sendData:[self jsonToData:json]
                        topic:[[Settings theGeneralTopicInMOC:CoreData.sharedInstance.mainMOC] stringByAppendingString:@"/dump"]
                   topicAlias:@(4)
                          qos:[Settings intForKey:@"qos_preference"
                                            inMOC:CoreData.sharedInstance.mainMOC]
                       retain:NO];
}

- (void)status {
    NSMutableDictionary *json = [[NSMutableDictionary alloc] init];
    json[@"_type"] = @"status";

    NSMutableDictionary *iOS = [NSMutableDictionary dictionary];
    
    iOS[@"version"] = [NSBundle mainBundle].infoDictionary[@"CFBundleVersion"];
    iOS[@"locale"] = [NSLocale currentLocale].localeIdentifier;
    iOS[@"localeUsesMetricSystem"] = [NSNumber numberWithBool:[NSLocale currentLocale].usesMetricSystem];

    UIBackgroundRefreshStatus status = [UIApplication sharedApplication].backgroundRefreshStatus;
    switch (status) {
        case UIBackgroundRefreshStatusAvailable:
            iOS[@"backgroundRefreshStatus"] = @"UIBackgroundRefreshStatusAvailable";
            break;
        case UIBackgroundRefreshStatusDenied:
            iOS[@"backgroundRefreshStatus"] = @"UIBackgroundRefreshStatusDenied";
            break;
        case UIBackgroundRefreshStatusRestricted:
            iOS[@"backgroundRefreshStatus"] = @"UIBackgroundRefreshStatusRestricted";
            break;
    }
    
    switch([LocationManager sharedInstance].locationManagerAuthorizationStatus) {
        case kCLAuthorizationStatusNotDetermined:
            iOS[@"locationManagerAuthorizationStatus"] = @"kCLAuthorizationStatusNotDetermined";
            break;
        case kCLAuthorizationStatusRestricted:
            iOS[@"locationManagerAuthorizationStatus"] = @"kCLAuthorizationStatusRestricted";
            break;
        case kCLAuthorizationStatusDenied:
            iOS[@"locationManagerAuthorizationStatus"] = @"kCLAuthorizationStatusDenied";
            break;
        case kCLAuthorizationStatusAuthorizedAlways:
            iOS[@"locationManagerAuthorizationStatus"] = @"kCLAuthorizationStatusAuthorizedAlways";
            break;
        case kCLAuthorizationStatusAuthorizedWhenInUse:
            iOS[@"locationManagerAuthorizationStatus"] = @"kCLAuthorizationStatusAuthorizedWhenInUse";
            break;
    }
    
    switch([LocationManager sharedInstance].altimeterAuthorizationStatus) {
        case CMAuthorizationStatusDenied:
            iOS[@"altimeterAuthorizationStatus"] = @"CMAuthorizationStatusDenied";
            break;
        case CMAuthorizationStatusAuthorized:
            iOS[@"altimeterAuthorizationStatus"] = @"CMAuthorizationStatusAuthorized";
            break;
        case CMAuthorizationStatusRestricted:
            iOS[@"altimeterAuthorizationStatus"] = @"CMAuthorizationStatusRestricted";
            break;
        case CMAuthorizationStatusNotDetermined:
            iOS[@"altimeterAuthorizationStatus"] = @"CMAuthorizationStatusNotDetermined";
            break;
    }
    iOS[@"altimeterIsRelativeAltitudeAvailable"] = [NSNumber numberWithBool:[LocationManager sharedInstance].altimeterIsRelativeAltitudeAvailable];
    
    UIDevice *device = [UIDevice currentDevice];
    //iOS[@"deviceName"] = device.name;
    iOS[@"deviceSystemName"] = device.systemName;
    iOS[@"deviceSystemVersion"] = device.systemVersion;
    iOS[@"deviceModel"] = device.model;
    //iOS[@"deviceLocalizedModel"] = device.localizedModel;
    iOS[@"deviceIdentifierForVendor"] = device.identifierForVendor.UUIDString;
    switch (device.userInterfaceIdiom) {
        case UIUserInterfaceIdiomUnspecified:
            iOS[@"deviceUserInterfaceIdiom"] = @"UIUserInterfaceIdiomUnspecified";
            break;
        case UIUserInterfaceIdiomPhone:
            iOS[@"deviceUserInterfaceIdiom"] = @"UIUserInterfaceIdiomPhone";
            break;
        case UIUserInterfaceIdiomPad:
            iOS[@"deviceUserInterfaceIdiom"] = @"UIUserInterfaceIdiomPad";
            break;
        case UIUserInterfaceIdiomTV:
            iOS[@"deviceUserInterfaceIdiom"] = @"UIUserInterfaceIdiomTV";
            break;
        case UIUserInterfaceIdiomCarPlay:
            iOS[@"deviceUserInterfaceIdiom"] = @"UIUserInterfaceIdiomCarPlay";
            break;
        case UIUserInterfaceIdiomMac:
            iOS[@"deviceUserInterfaceIdiom"] = @"UIUserInterfaceIdiomMac";
            break;
        case UIUserInterfaceIdiomVision:
            iOS[@"deviceUserInterfaceIdiom"] = @"UIUserInterfaceIdiomVision";
            break;
    }

    json[@"iOS"] = iOS;
    
    [self.connection sendData:[self jsonToData:json]
                        topic:[[Settings theGeneralTopicInMOC:CoreData.sharedInstance.mainMOC] stringByAppendingString:@"/status"]
                   topicAlias:@(8)
                          qos:[Settings intForKey:@"qos_preference"
                                            inMOC:CoreData.sharedInstance.mainMOC]
                       retain:NO];
}

- (void)performAction:(NSDictionary *)dictionary {
    NSString *content = dictionary[@"content"];
    if (content && ![content isKindOfClass:[NSString class]]) {
        DDLogWarn(@"[OwnTracksAppDelegate performAction] content is not a string");
        content = nil;
    }
    
    NSString *url = dictionary[@"url"];
    if (url && ![url isKindOfClass:[NSString class]]) {
        DDLogWarn(@"[OwnTracksAppDelegate performAction] url is not a string");
        url = nil;
    }

    NSString *notificationMessage = dictionary[@"notification"];
    if (notificationMessage && ![notificationMessage isKindOfClass:[NSString class]]) {
        DDLogWarn(@"[OwnTracksAppDelegate performAction] notification is not a string");
        notificationMessage = nil;
    }

    NSNumber *external = dictionary[@"extern"];
    if (external && ![external isKindOfClass:[NSNumber class]]) {
        DDLogWarn(@"[OwnTracksAppDelegate performAction] external is not a number");
        external = nil;
    }

    
    [Settings setString:content
                 forKey:SETTINGS_ACTION
                  inMOC:CoreData.sharedInstance.mainMOC];
    [Settings setString:url
                 forKey:SETTINGS_ACTIONURL
                  inMOC:CoreData.sharedInstance.mainMOC];
    [Settings setBool:external.boolValue
               forKey:SETTINGS_ACTIONEXTERN
                inMOC:CoreData.sharedInstance.mainMOC];
    
    if (notificationMessage) {
        UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
        content.body = notificationMessage;
        content.sound = [UNNotificationSound defaultSound];
        UNTimeIntervalNotificationTrigger* trigger = [UNTimeIntervalNotificationTrigger
                                                      triggerWithTimeInterval:1.0
                                                      repeats:NO];
        NSString *notificationIdentifier = [NSString stringWithFormat:@"action%f",
                                            [NSDate date].timeIntervalSince1970];
        DDLogVerbose(@"[OwnTracksAppDelegate] notificationIdentifier:%@", notificationIdentifier);
        
        UNNotificationRequest* request = [UNNotificationRequest         requestWithIdentifier:notificationIdentifier
                                                                                      content:content
                                                                                      trigger:trigger];
        UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
        [center addNotificationRequest:request withCompletionHandler:nil];
        
        [History historyInGroup:NSLocalizedString(@"Notification",
                                                  @"Alert message header for notification messages")
                       withText:notificationMessage
                             at:nil
                          inMOC:[CoreData sharedInstance].mainMOC
                        maximum:[Settings theMaximumHistoryInMOC:[CoreData sharedInstance].mainMOC]];
        [CoreData.sharedInstance sync:CoreData.sharedInstance.mainMOC];
        
        [self.navigationController alert:
             NSLocalizedString(@"Notification",
                               @"Alert message header for notification messages")
                                 message:notificationMessage
                            dismissAfter:2.0
        ];
    }
    
    if (content || url) {
        if (url && ![url isEqualToString:self.action]) {
            self.action = url;
        } else {
            if (content && ![content isEqualToString:self.action]) {
                self.action = content;
            }
        }
    } else {
        self.action = nil;
    }
}

- (void)performResponse:(NSDictionary *)dictionary {
    if ([[Tours sharedInstance] processResponse:dictionary]) {
    } else {
    }
}

- (void)performSetConfiguration:(NSDictionary *)dictionary {
    NSDictionary *configuration = dictionary[@"configuration"];
    if (configuration && [configuration isKindOfClass:[NSDictionary class]]) {
        NSError *error = [Settings fromDictionary:configuration
                                            inMOC:CoreData.sharedInstance.mainMOC];

        if (error) {
            DDLogError(@"[OwnTracksAppDelegate performSetConfiguration] error %@", error);
        }
    } else {
        DDLogWarn(@"[OwnTracksAppDelegate performSetConfiguration] no valid configuration");
    }
    [CoreData.sharedInstance sync:CoreData.sharedInstance.mainMOC];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"reload" object:nil];
    self.configLoad = [NSDate date];
    [self reconnect];
}

- (void)performSetWaypoints:(NSDictionary *)dictionary {
    NSDictionary *waypoints = dictionary[@"waypoints"];
    if (waypoints && [waypoints isKindOfClass:[NSDictionary class]]) {
        [Settings waypointsFromDictionary:waypoints
                                    inMOC:CoreData.sharedInstance.mainMOC];
    } else {
        DDLogWarn(@"[OwnTracksAppDelegate performSetWaypoints] no valid waypoints");
    }
}

- (void)performClearWaypoints:(NSDictionary *)dictionary {
    [Settings clearWaypoints:CoreData.sharedInstance.mainMOC];
}

- (void)waypoints {
    NSDictionary *json = [Settings waypointsToDictionaryInMOC:CoreData.sharedInstance.mainMOC];
    [self.connection sendData:[self jsonToData:json]
                        topic:[[Settings theGeneralTopicInMOC:CoreData.sharedInstance.mainMOC] stringByAppendingString:@"/waypoints"]
                   topicAlias:@(5)
                          qos:[Settings intForKey:@"qos_preference"
                                            inMOC:CoreData.sharedInstance.mainMOC]
                       retain:NO];
}

- (void)stepsFrom:(NSNumber *)from to:(NSNumber *)to {
    NSDate *toDate;
    NSDate *fromDate;
    if (to && [to isKindOfClass:[NSNumber class]]) {
        toDate = [NSDate dateWithTimeIntervalSince1970:to.doubleValue];
    } else {
        toDate = [NSDate date];
    }
    if (from && [from isKindOfClass:[NSNumber class]]) {
        fromDate = [NSDate dateWithTimeIntervalSince1970:from.doubleValue];
    } else {
        NSDateComponents *components = [[NSCalendar currentCalendar]
                                        components: NSCalendarUnitDay |
                                        NSCalendarUnitHour |
                                        NSCalendarUnitMinute |
                                        NSCalendarUnitSecond |
                                        NSCalendarUnitMonth |
                                        NSCalendarUnitYear
                                        fromDate:toDate];
        components.hour = 0;
        components.minute = 0;
        components.second = 0;
        
        fromDate = [[NSCalendar currentCalendar] dateFromComponents:components];
    }
    
    DDLogInfo(@"[OwnTracksAppDelegate] isStepCountingAvailable %d",
              [CMPedometer isStepCountingAvailable]);
    DDLogInfo(@"[OwnTracksAppDelegate] isFloorCountingAvailable %d",
              [CMPedometer isFloorCountingAvailable]);
    DDLogInfo(@"[OwnTracksAppDelegate] isDistanceAvailable %d",
              [CMPedometer isDistanceAvailable]);
    
    if (!self.pedometer) {
        self.pedometer = [[CMPedometer alloc] init];
    }
    [self.pedometer queryPedometerDataFromDate:fromDate
                                        toDate:toDate
                                   withHandler:
     ^(CMPedometerData *pedometerData, NSError *error) {
        DDLogVerbose(@"[OwnTracksAppDelegate] StepCounter queryPedometerDataFromDate %ld %ld %ld %ld %@",
                     [pedometerData.numberOfSteps longValue],
                     [pedometerData.floorsAscended longValue],
                     [pedometerData.floorsDescended longValue],
                     [pedometerData.distance longValue],
                     error.localizedDescription);
        dispatch_async(dispatch_get_main_queue(), ^{
            
            NSMutableDictionary *json = [[NSMutableDictionary alloc] init];
            json[@"_type"] = @"steps";
            json[@"tst"] = [NSNumber doubleValueWithZeroDecimals:[NSDate date].timeIntervalSince1970];
            json[@"from"] = [NSNumber doubleValueWithZeroDecimals:fromDate.timeIntervalSince1970];
            json[@"to"] = [NSNumber doubleValueWithZeroDecimals:toDate.timeIntervalSince1970];
            
            if (pedometerData) {
                json[@"steps"] = pedometerData.numberOfSteps;
                if (pedometerData.floorsAscended) {
                    json[@"floorsup"] = pedometerData.floorsAscended;
                }
                if (pedometerData.floorsDescended) {
                    json[@"floorsdown"] = pedometerData.floorsDescended;
                }
                if (pedometerData.distance) {
                    json[@"distance"] = pedometerData.distance.zeroDecimals;
                }
            } else {
                json[@"steps"] = @(-1);
            }
            
            NSManagedObjectContext *moc = CoreData.sharedInstance.mainMOC;
            MQTTQosLevel qos = [Settings intForKey:@"qos_preference"
                                             inMOC:moc];
            [self.connection sendData:[self jsonToData:json]
                                topic:[[Settings theGeneralTopicInMOC:CoreData.sharedInstance.mainMOC] stringByAppendingString:@"/step"]
                           topicAlias:@(6)
                                  qos:qos
                               retain:NO];
        });
    }];
}

#pragma actions

- (BOOL)sendNow:(CLLocation *)location withPOI:(NSString *)poi {
    DDLogInfo(@"[OwnTracksAppDelegate] sendNow %@ withPOI %@", location, poi);
    
    if (self.sendNowActivity) {
        [self.sendNowActivity invalidate];
    }
    self.sendNowActivity =
    [[NSUserActivity alloc]
     initWithActivityType:@"org.mqttitude.MQTTitude.sendNow"];
    self.sendNowActivity.title = NSLocalizedString(@"Send location now", @"User Activity (Siri) Send location now");
    self.sendNowActivity.eligibleForSearch = true;
    self.sendNowActivity.eligibleForPrediction = true;
    [self.sendNowActivity becomeCurrent];
    return [self publishLocation:location trigger:@"u" withPOI:poi];
}

- (void)reportLocation {
    DDLogInfo(@"[OwnTracksAppDelegate] reportLocation");
    CLLocation *location = [LocationManager sharedInstance].location;
    [self publishLocation:location trigger:@"r" withPOI:nil];
}

- (void)connectionOff {
    DDLogInfo(@"[OwnTracksAppDelegate] connectionOff");
    [self.connection disconnect];
}

- (void)terminateSession {
    DDLogInfo(@"[OwnTracksAppDelegate] terminateSession");
    
    [self connectionOff];
    [[OwnTracking sharedInstance] syncProcessing];
    [[LocationManager sharedInstance] resetRegions];
    [self.connection reset];
    [Friend deleteAllFriendsInManagedObjectContext:CoreData.sharedInstance.mainMOC];
    [[CoreData sharedInstance] sync:CoreData.sharedInstance.mainMOC];
}

- (void)reconnect {
    DDLogInfo(@"[OwnTracksAppDelegate] reconnect");
    [self.connection disconnect];
    [self connect];
}

- (BOOL)publishLocation:(CLLocation *)location
                trigger:(NSString *)trigger
                withPOI:(NSString *)poi {
    NSManagedObjectContext *moc = CoreData.sharedInstance.mainMOC;
    
    if (location &&
        CLLocationCoordinate2DIsValid(location.coordinate) &&
        location.coordinate.latitude != 0.0 &&
        location.coordinate.longitude != 0.0 &&
        [Settings validIdsInMOC:moc]) {
        
        int ignoreInaccurateLocations =
        [Settings intForKey:@"ignoreinaccuratelocations_preference"
                      inMOC:moc];
        DDLogVerbose(@"[OwnTracksAppDelegate] location accuracy:%fm, ignoreIncacurationLocations:%dm",
                     location.horizontalAccuracy, ignoreInaccurateLocations);
        
        if (ignoreInaccurateLocations == 0 || location.horizontalAccuracy < ignoreInaccurateLocations) {
            Friend *friend = [Friend friendWithTopic:[Settings theGeneralTopicInMOC:moc]
                              inManagedObjectContext:moc];
            if (friend) {
                for (Region *anyRegion in friend.hasRegions) {
                    if (anyRegion.CLregion.isFollow) {
                        if ((anyRegion.radius).doubleValue > 0) {
                            anyRegion.lat = @(location.coordinate.latitude);
                            anyRegion.lon = @(location.coordinate.longitude);
                            double time = [anyRegion.CLregion.identifier substringFromIndex:1].doubleValue;
                            if (time == HUGE_VAL || time == -HUGE_VAL || time == 0.0) {
                                time = 30.0;
                            }
                            if (location.speed >= 0.0) {
                                anyRegion.radius = @(MAX(location.speed * time, 50.0));
                            } else {
                                anyRegion.radius = @(50.0);
                            }
                            [[LocationManager sharedInstance] startRegion:anyRegion.CLregion];
                        }
                    }
                }
                
                friend.tid = [Settings stringForKey:@"trackerid_preference"
                                              inMOC:moc];
                
                OwnTracking *ownTracking = [OwnTracking sharedInstance];
                NSDate *createdAt = location.timestamp;
                if (fabs(location.timestamp.timeIntervalSince1970 -
                         [NSDate date].timeIntervalSince1970) > 1.0) {
                    createdAt = [NSDate date];
                }
                
                NSNumber *batteryLevel = [NSNumber numberWithFloat:[UIDevice currentDevice].batteryLevel];
                
                NSString *tag = [[NSUserDefaults standardUserDefaults] stringForKey:@"tag"];
                
                Waypoint *waypoint = [ownTracking addWaypointFor:friend
                                                        location:location
                                                       createdAt:createdAt
                                                         trigger:trigger
                                                             poi:poi
                                                             tag:tag
                                                         battery:batteryLevel];
                if (waypoint) {
                    [CoreData.sharedInstance sync:moc];
                    
                    NSDictionary *json = [[OwnTracking sharedInstance] waypointAsJSON:waypoint];
                    if (json) {
                        NSData *data = [self jsonToData:json];
                        [self.connection sendData:data
                                            topic:[Settings theGeneralTopicInMOC:moc]
                                       topicAlias:@(1)
                                              qos:[Settings intForKey:@"qos_preference"
                                                                inMOC:moc]
                                           retain:[Settings boolForKey:@"retain_preference"
                                                                 inMOC:moc]];
                    } else {
                        DDLogError(@"[OwnTracksAppDelegate] no JSON created from waypoint %@", waypoint);
                        return FALSE;
                    }
                    [ownTracking limitWaypointsFor:friend
                                         toMaximum:[Settings intForKey:@"positions_preference"
                                                                 inMOC:moc]];
                } else {
                    DDLogError(@"[OwnTracksAppDelegate] waypoint creation failed from friend %@, location %@", friend, location);
                    return FALSE;
                }
                
                if ([UIDevice currentDevice].isBatteryMonitoringEnabled) {
                    UIDeviceBatteryState batteryState = [UIDevice currentDevice].batteryState;
                    float batteryLevel = [UIDevice currentDevice].batteryLevel;
                    if ([LocationManager sharedInstance].monitoring == LocationMonitoringMove) {
                        int downgrade = [Settings intForKey:@"downgrade_preference"
                                                      inMOC:moc];
                        
                        if (batteryState != UIDeviceBatteryStateFull && batteryState != UIDeviceBatteryStateCharging && batteryLevel < downgrade / 100.0) {
                            // Move Mode, but battery is not full, not charging and less than downgrade%
                            [[NSUserDefaults standardUserDefaults] setBool:TRUE forKey:@"downgraded"];
                            LocationManager.sharedInstance.monitoring = LocationMonitoringSignificant;
                            [Settings setInt:(int)[LocationManager sharedInstance].monitoring
                                      forKey:@"monitoring_preference" inMOC:moc];
                            [CoreData.sharedInstance sync:moc];
                            [self background];
                        } else {
                            // Move Mode, battery is full, charging or has more than downgrade%
                        }
                    } else {
                        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"downgraded"]) {
                            if (batteryState == UIDeviceBatteryStateFull || batteryState == UIDeviceBatteryStateCharging) {
                                // not Move Mode, previously downgraded and battery is charging or full
                                [[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:@"downgraded"];
                                LocationManager.sharedInstance.monitoring = LocationMonitoringMove;
                                [Settings setInt:(int)[LocationManager sharedInstance].monitoring
                                          forKey:@"monitoring_preference" inMOC:moc];
                                [CoreData.sharedInstance sync:moc];
                                [self background];
                            } else {
                                // not Move Mode, previously downgraded but battery is not charging nor full
                            }
                        } else {
                            // not Move Mode, but not previously downgraded
                        }
                    }
                }
                
            } else {
                DDLogError(@"[OwnTracksAppDelegate] no friend found");
                return FALSE;
            }
        }
    } else {
        DDLogError(@"[OwnTracksAppDelegate] invalid location");
        return FALSE;
    }
    return TRUE;
}

- (void)sendEmpty:(NSString *)topic {
    DDLogInfo(@"[OwnTracksAppDelegate] sendEmpty");
    NSManagedObjectContext *moc = CoreData.sharedInstance.mainMOC;
    MQTTQosLevel qos = [Settings intForKey:@"qos_preference"
                                     inMOC:moc];
    [self.connection sendData:nil
                        topic:topic
                   topicAlias:nil
                          qos:qos
                       retain:YES];
}

- (void)sendRegion:(Region *)region {
    DDLogInfo(@"[OwnTracksAppDelegate] sendRegion %@", region);
    NSManagedObjectContext *moc = CoreData.sharedInstance.mainMOC;
    
    if ([Settings validIdsInMOC:moc]) {
        MQTTQosLevel qos = [Settings intForKey:@"qos_preference"
                                         inMOC:moc];
        NSMutableDictionary *json = [[[OwnTracking sharedInstance] regionAsJSON:region] mutableCopy];
        NSData *data = [self jsonToData:json];
        [self.connection sendData:data
                            topic:[[Settings theGeneralTopicInMOC:moc] stringByAppendingString:@"/waypoint"]
                       topicAlias:@(7)
                              qos:qos
                           retain:NO];
    }
}

#pragma internal helpers

- (void)connect {
    NSManagedObjectContext *moc = CoreData.sharedInstance.mainMOC;
    
    BOOL usePassword = [Settings theMqttUsePasswordInMOC:moc];
    NSString *password = nil;
    if (usePassword) {
        password = [Settings theMqttPassInMOC:moc];
    }
    if ([Settings intForKey:@"mode" inMOC:moc] == CONNECTION_MODE_HTTP) {
        self.connection.key = [Settings stringForKey:@"secret_preference"
                                               inMOC:moc];
        [self.connection connectHTTP:[Settings stringForKey:@"url_preference"
                                                      inMOC:moc]
                                auth:[Settings theMqttAuthInMOC:moc]
                                user:[Settings theMqttUserInMOC:moc]
                                pass:password
                              device:[Settings theDeviceIdInMOC:moc]
                         httpHeaders:[Settings stringForKey:@"httpheaders_preference"
                                                      inMOC:moc]];
    } else {
        NSURL *directoryURL = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory
                                                                     inDomain:NSUserDomainMask
                                                            appropriateForURL:nil
                                                                       create:YES
                                                                        error:nil];
        NSArray *certificates = nil;
        NSString *fileName = [Settings stringForKey:@"clientpkcs" inMOC:moc];
        NSString *passPhrase = [Settings stringForKey:@"passphrase" inMOC:moc];
        if (fileName && fileName.length) {
            DDLogInfo(@"[OwnTracksAppDelegate] getting p12 filename:%@ passphrase:%@",
                      fileName, passPhrase);
            NSString *clientPKCSPath = [directoryURL.path stringByAppendingPathComponent:fileName];
            certificates = [MQTTTransport clientCertsFromP12:clientPKCSPath
                                                  passphrase:passPhrase];
            if (!certificates) {
                DDLogWarn(@"[OwnTracksAppDelegate] TLS Client Certificate incorrect file or passphrase");
                [self.navigationController alert:
                     NSLocalizedString(@"TLS Client Certificate",
                                       @"Heading for certificate error message")
                                         message:
                     NSLocalizedString(@"incorrect file or passphrase",
                                       @"certificate error message")
                ];
            }
        }
        
        MQTTQosLevel subscriptionQos =[Settings intForKey:@"subscriptionqos_preference"
                                                    inMOC:moc];
        NSArray *subscriptions = [[NSArray alloc] init];
        if ([Settings boolForKey:@"sub_preference" inMOC:moc]) {
            subscriptions = [[Settings theSubscriptionsInMOC:moc] componentsSeparatedByCharactersInSet:
                             [NSCharacterSet whitespaceCharacterSet]];
        }
        
        self.connection.subscriptions = subscriptions;
        self.connection.subscriptionQos = subscriptionQos;
        
        NSMutableDictionary *json = [[NSMutableDictionary alloc] init];
        json[@"_type"] = @"lwt";
        json[@"tst"] = [NSNumber doubleValueWithZeroDecimals:[NSDate date].timeIntervalSince1970];
        
        self.connection.key = [Settings stringForKey:@"secret_preference"
                                               inMOC:moc];
        
        [self.connection connectTo:[Settings theHostInMOC:moc]
                              port:[Settings intForKey:@"port_preference" inMOC:moc]
                                ws:[Settings boolForKey:@"ws_preference" inMOC:moc]
                               tls:[Settings boolForKey:@"tls_preference" inMOC:moc]
                   protocolVersion:[Settings intForKey:SETTINGS_PROTOCOL inMOC:moc]
                         keepalive:[Settings intForKey:@"keepalive_preference" inMOC:moc]
                             clean:[Settings intForKey:@"clean_preference" inMOC:moc]
                              auth:[Settings theMqttAuthInMOC:moc]
                              user:[Settings theMqttUserInMOC:moc]
                              pass:password
                         willTopic:[Settings theWillTopicInMOC:moc]
                              will:[self jsonToData:json]
                           willQos:[Settings theWillQosInMOC:moc]
                    willRetainFlag:[Settings theWillRetainFlagInMOC:moc]
                      withClientId:[Settings theClientIdInMOC:moc]
        allowUntrustedCertificates:[Settings boolForKey:@"allowinvalidcerts" inMOC:moc]
                      certificates:certificates];
    }
}

- (NSData *)jsonToData:(NSDictionary *)jsonObject {
    NSData *data;
    if ([NSJSONSerialization isValidJSONObject:jsonObject]) {
        NSError *error;
        data = [NSJSONSerialization dataWithJSONObject:jsonObject
                                               options:NSJSONWritingSortedKeys
                                                 error:&error];
        if (!data) {
            DDLogError(@"[OwnTracksAppDelegate] dataWithJSONObject failed: %@ %@ %@",
                       error.localizedDescription,
                       error.userInfo,
                       [jsonObject description]);
        }
    } else {
        DDLogError(@"[OwnTracksAppDelegate] isValidJSONObject failed %@", [jsonObject description]);
    }
    return data;
}

- (BOOL)application:(UIApplication *)application
continueUserActivity:(nonnull NSUserActivity *)userActivity
 restorationHandler:(nonnull void (^)(NSArray<id<UIUserActivityRestoring>> * _Nullable))restorationHandler {
    DDLogInfo(@"application continueUserActivity:%@", userActivity.activityType);
    
    if ([userActivity.activityType isEqualToString:@"org.mqttitude.MQTTitude.sendNow"] ||
        [userActivity.activityType isEqualToString:@"OwnTracksSendNowIntent"]) {
        if ([self sendNow:[LocationManager sharedInstance].location withPOI:nil]) {
            [self.navigationController alert:
                 NSLocalizedString(@"Location",
                                   @"Header of an alert message regarding a location")
                                     message:
                 NSLocalizedString(@"publish queued on user request",
                                   @"content of an alert message regarding user publish")
                                dismissAfter:1
            ];
        } else {
            [self.navigationController alert:
             NSLocalizedString(@"Location",
                               @"Header of an alert message regarding a location")
                                     message:
             NSLocalizedString(@"publish queued on user request",
                               @"content of an alert message regarding user publish")];
        }
        
        return YES;
    } else if ([userActivity.activityType isEqualToString:@"OwnTracksChangeMonitoringIntent"]) {
        OwnTracksChangeMonitoringIntent *intent = (OwnTracksChangeMonitoringIntent *)userActivity.interaction.intent;
        LocationMonitoring monitoring = [LocationManager sharedInstance].monitoring;
        switch (intent.monitoring) {
            case OwnTracksEnumQuiet:
                monitoring = LocationMonitoringQuiet;
                break;
            case OwnTracksEnumManual:
                monitoring = LocationMonitoringManual;
                break;
            case OwnTracksEnumSignificant:
                monitoring = LocationMonitoringSignificant;
                break;
            case OwnTracksEnumMove:
                monitoring = LocationMonitoringMove;
                break;
            default:
                break;
        }
        [LocationManager sharedInstance].monitoring = monitoring;
        [[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:@"downgraded"];
        NSManagedObjectContext *moc = CoreData.sharedInstance.mainMOC;
        [Settings setInt:(int)[LocationManager sharedInstance].monitoring
                  forKey:@"monitoring_preference" inMOC:moc];
        [CoreData.sharedInstance sync:moc];
        
        return YES;
    } else if ([userActivity.activityType isEqualToString:@"OwnTracksTagIntent"]) {
        OwnTracksTagIntent *intent = (OwnTracksTagIntent *)userActivity.interaction.intent;
        NSString *tag = intent.tag;
        if (tag && tag.length) {
            [[NSUserDefaults standardUserDefaults] setObject:tag forKey:@"tag"];
        } else {
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"tag"];
        }
        
        return YES;
    } else if ([userActivity.activityType isEqualToString:@"OwnTracksPointOfInterestIntent"]) {
        OwnTracksPointOfInterestIntent *intent = (OwnTracksPointOfInterestIntent *)userActivity.interaction.intent;
        NSString *name = intent.name;
        if ([self sendNow:[LocationManager sharedInstance].location withPOI:name]) {
            [self.navigationController alert:
                 NSLocalizedString(@"Location",
                                   @"Header of an alert message regarding a location")
                                     message:
                 NSLocalizedString(@"publish queued on user request",
                                   @"content of an alert message regarding user publish")
                                dismissAfter:1
            ];
        } else {
            [self.navigationController alert:
             NSLocalizedString(@"Location",
                               @"Header of an alert message regarding a location")
                                     message:
             NSLocalizedString(@"publish queued on user request",
                               @"content of an alert message regarding user publish")];
        }
        return YES;
    }
    return NO;
}

- (void)setupLeftMenu {
    OwnTracksLeftMenuVC* leftMenuVC = [[OwnTracksLeftMenuVC alloc] initWithNibName:@"OwnTracksLeftMenuVC" bundle:nil];
    
    SideMenuSettings *_settings = [[SideMenuSettings alloc] init];
    [_settings setPresentationStyle:SideMenuPresentationStyle.menuSlideIn];
    SideMenuPresentationStyle *_selectedPresentationStyle = _settings.presentationStyle;
    _selectedPresentationStyle.presentingScaleFactor = 0.9;

    float width = 300;
    [_settings setMenuWidth:width];

    SideMenuNavigationController *_sideMenu = [[SideMenuNavigationController alloc] initWithRootViewController:leftMenuVC settings:_settings];

    [_sideMenu setSideMenuDelegate:self];
    [_sideMenu setNavigationBarHidden:YES];
    [_sideMenu setLeftSide:YES];
    [_sideMenu setStatusBarEndAlpha:0];
                
    [[SideMenuManager defaultManager] setLeftMenuNavigationController:_sideMenu];
}

-(UIViewController*)initialViewController {
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"Storyboard" bundle:nil];
    ViewController *_view = [storyboard instantiateViewControllerWithIdentifier:@"ViewController"];
    UINavigationController* nav = [[UINavigationController alloc] initWithRootViewController:_view];
    return nav;
}

#if APNS
#pragma Remote Notifications
- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    
    NSString *deviceHexString = [[NSString alloc] init];
    for (int i = 0; i < deviceToken.length; i++) {
        unsigned char c;
        [deviceToken getBytes:&c range:NSMakeRange(i, 1)];
        deviceHexString = [deviceHexString stringByAppendingFormat:@"%02X", c];
    }
    DDLogInfo(@"[OwnTracksAppDelegate] didRegisterForRemoteNotificationsWithDeviceToken: %@",
              deviceHexString);
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    DDLogError(@"[OwnTracksAppDelegate] didFailToRegisterForRemoteNotificationsWithError: %@",
               error.localizedDescription);
    
}

#endif

@end

