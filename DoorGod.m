//
//  DoorGod.m
//  
//
//  Created by jia on 15/9/22.
//
//

#import "DoorGod.h"
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <AddressBook/AddressBook.h>
#import <CoreLocation/CoreLocation.h>
#import <Photos/Photos.h>

@interface DoorGod () <CLLocationManagerDelegate>

@property (nonatomic, copy) DGBlock completionHandler;

@end

@implementation DoorGod

+ (DoorGod *)sharedInstance
{
    static DoorGod *s_instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_instance = [[DoorGod alloc] init];
    });
    
    return s_instance;
}

+ (void)requestAccessOfPrivacy:(DGPrivacy)privacy completion:(DGBlock)completionHandler
{
    [self requestAccessOfPrivacy:privacy beforeRun:nil completion:completionHandler];

}
+ (void)requestAccessOfPrivacy:(DGPrivacy)privacy beforeRun:(BOOL (^)(void))beforeRun completion:(DGBlock)completionHandler
{
    if (nil != beforeRun && !beforeRun()) {
        return;
    }
    
    switch (privacy) {
        case kDGPrivacyContacts: {
            [self requestAccessOfContactsCompletion:completionHandler];
            break;
        }
        case kDGPrivacyCamera: {
            [self requestAccessOfCameraCompletion:completionHandler];
            break;
        }
        case kDGPrivacyPhotos: {
            [self requestAccessOfPhotosCompletion:completionHandler];
            break;
        }
        case kDGPrivacyMicrophone: {
            [self requestAccessOfMicrophoneCompletion:completionHandler];
            break;
        }
        case kDGPrivacyRemoteNotification: {
            [self requestAccessOfRemoteNotificationCompletion:completionHandler];
            break;
        }
        case kDGPrivacyLocation: {
            [self requestAccessOfLocationCompletion:completionHandler];
            break;
        }
        default: {
            if (nil != completionHandler) {
                completionHandler(NO, nil);
            }
            break;
        }
    }
}

+ (void)requestAccessOfRemoteNotificationCompletion:(DGBlock)completionHandler
{
    BOOL remoteNotiEnable = NO;
    NSError *error = nil;
    UIApplication *application = [UIApplication sharedApplication];
    if ([application respondsToSelector:@selector(isRegisteredForRemoteNotifications)]) {
        if (application.isRegisteredForRemoteNotifications) {
            UIUserNotificationSettings *settings = application.currentUserNotificationSettings;
            remoteNotiEnable = UIUserNotificationTypeNone != settings.types;
        } else {
            error = [NSError errorWithDomain:NSStringFromClass(self) code:-1 userInfo:@{NSLocalizedDescriptionKey: @"does not regist remote notification"}];
        }
    }
#if (__IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_8_0)
    else {
        remoteNotiEnable = UIRemoteNotificationTypeNone != application.enabledRemoteNotificationTypes;
    }
#endif
    
    if (nil != completionHandler) {
        completionHandler(remoteNotiEnable, error);
    }
}


+ (void)requestAccessOfCameraCompletion:(DGBlock)completionHandler
{
    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
        if (nil != completionHandler) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionHandler(granted, nil);
            });
        }
    }];
}

+ (void)requestAccessOfPhotosCompletion:(DGBlock)completionHandler
{
    if (Nil != PHPhotoLibrary.class) {
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
            if (nil != completionHandler) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completionHandler(status == PHAuthorizationStatusAuthorized, nil);
                });
            }
        }];
    } else {
        ALAssetsLibrary *lib = [[ALAssetsLibrary alloc] init];
        [lib enumerateGroupsWithTypes:ALAssetsGroupSavedPhotos usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
            if (nil != group) {
                if (nil != completionHandler) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completionHandler(YES, nil);
                    });
                }
            }
            
        } failureBlock:^(NSError *error) {
            if (nil != completionHandler) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completionHandler(NO, error);
                });
            }
        }];
    }
}

+ (void)requestAccessOfMicrophoneCompletion:(DGBlock)completionHandler
{
    [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
        if (nil != completionHandler) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionHandler(granted, nil);
            });
        }
    }];
}

+ (void)requestAccessOfContactsCompletion:(DGBlock)completionHandler
{
    switch (ABAddressBookGetAuthorizationStatus()) {
        case kABAuthorizationStatusAuthorized: {
            if (nil != completionHandler) {
                completionHandler(YES, nil);
            }
            break;
        }
        case kABAuthorizationStatusNotDetermined: {

            CFErrorRef cError = NULL;
            ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(NULL, &cError);
            NSError *nError = (__bridge_transfer NSError *)(cError);
            if (NULL != addressBook) {
                ABAddressBookRequestAccessWithCompletion(addressBook, ^(bool granted, CFErrorRef error) {
                    CFRelease(addressBook);
                    if (nil != completionHandler) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            completionHandler(granted, (__bridge NSError *)(error));
                        });
                    }
                });
            } else {
                if (nil != completionHandler) {
                    completionHandler(NO, nError);
                }
            }
            break;
        }
            
        default: {
            if (nil != completionHandler) {
                completionHandler(NO, nil);
            }
            break;
        }
    }
}

+ (void)requestAccessOfLocationCompletion:(DGBlock)completionHandler
{
    
    if (!CLLocationManager.locationServicesEnabled) {
        if (nil != completionHandler) {
            completionHandler(NO, nil);
        }
        return;
    }
    
    switch (CLLocationManager.authorizationStatus) {
        case kCLAuthorizationStatusAuthorizedAlways:
        case kCLAuthorizationStatusAuthorizedWhenInUse: {
            if (nil != completionHandler) {
                completionHandler(YES, nil);
            }
            break;
        }
        case kCLAuthorizationStatusNotDetermined: {
            
            //由于IOS8中定位的授权机制改变 需要进行手动授权
            CLLocationManager  *locationManager = [[CLLocationManager alloc] init];
            //获取授权认证
            [locationManager requestAlwaysAuthorization];
            [locationManager requestWhenInUseAuthorization];
            locationManager.delegate = self.sharedInstance;
            self.sharedInstance.completionHandler = completionHandler;
            [locationManager startUpdatingLocation];
            
            break;
        }
            
        default: {
            if (nil != completionHandler) {
                completionHandler(NO, nil);
            }
            break;
        }
    }
}


#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations
{
    [manager startUpdatingLocation];
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    if (nil != _completionHandler) {
        _completionHandler(status == kCLAuthorizationStatusAuthorizedAlways || status == kCLAuthorizationStatusAuthorizedWhenInUse , nil);
    }
}

@end
