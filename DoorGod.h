//
//  DoorGod.h
//  
//
//  Created by jia on 15/9/22.
//
//

#import <Foundation/Foundation.h>

typedef void(^DGBlock)(BOOL granted, NSError *error);

typedef NS_ENUM(NSInteger, DGPrivacy) {
    kDGPrivacyCamera,
    kDGPrivacyPhotos,
    kDGPrivacyLocation,
    kDGPrivacyContacts,
    kDGPrivacyMicrophone,
    kDGPrivacyRemoteNotification
};

@interface DoorGod : NSObject

+ (void)requestAccessOfPrivacy:(DGPrivacy)privacy completion:(DGBlock)completionHandler;
+ (void)requestAccessOfPrivacy:(DGPrivacy)privacy beforeRun:(BOOL(^)(void))beforeRun completion:(DGBlock)completionHandler;

@end

