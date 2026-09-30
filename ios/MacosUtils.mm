#include "MacosUtils.h"
#include <QDebug>
#include <QPointer>
#include <QSysInfo>

// #import <Foundation/Foundation.h>
// #import <LocalAuthentication/LocalAuthentication.h>

#ifdef Q_OS_IOS
#import <UIKit/UIKit.h>
#import <sys/utsname.h>
#endif

#if defined(Q_OS_MACOS) && !defined(QT_DEBUG)
// #import <Sparkle/Sparkle.h>
#endif

ApplePlatformUtils::ApplePlatformUtils(QObject *parent) : QObject(parent) {}

// #if defined(Q_OS_MACOS) && !defined(QT_DEBUG)
// @interface UpdaterDelegate
//     : NSObject <SPUUpdaterDelegate, SPUStandardUserDriverDelegate>
// @end

// @implementation UpdaterDelegate

// - (NSString *)feedURLStringForUpdater:(SPUUpdater *)updater {
//   // TODO: замінити на appcast RodON
//   return @"https://rodon.example.com/appcast.xml";
// }

// - (BOOL)allowsSkippingUpdates:(SPUUpdater *)updater {
//   return NO;
// }
// - (BOOL)updaterShouldPromptForPermissionToCheckForUpdates:
//     (SPUUpdater *)updater {
//   return NO;
// }
// - (BOOL)standardUserDriverShouldShowUpdateAlertForItem:(SUAppcastItem *)item
// {
//   return YES;
// }
// - (NSSet<NSString *> *)standardUserDriverAllowedSystemVersionRequirementKeys:
//     (SPUStandardUserDriver *)userDriver {
//   return [NSSet set];
// }
// - (BOOL)standardUserDriverShouldHandleInformationalUpdatesOnly:
//     (SPUStandardUserDriver *)userDriver {
//   return NO;
// }
// - (SPUUserUpdateChoice)
//     standardUserDriverWillHandleStandardUserUpdateRequest:
//         (SPUStandardUserDriver *)userDriver
//                                                   forItem:
//                                                       (SUAppcastItem *)item {
//   return SPUUserUpdateChoiceInstall;
// }
// - (NSTimeInterval)
//     standardUserDriverRemindMeLaterInterval:(SPUStandardUserDriver
//     *)userDriver
//                                     forItem:(SUAppcastItem *)item {
//   return 24 * 60 * 60;
// }
// @end

// void ApplePlatformUtils::init_sparkle() {
//   UpdaterDelegate *delegate = [[UpdaterDelegate alloc] init];
//   SPUStandardUpdaterController *updaterController =
//       [[SPUStandardUpdaterController alloc] initWithStartingUpdater:YES
//                                                     updaterDelegate:delegate
//                                                  userDriverDelegate:delegate];
//   [updaterController checkForUpdates:nil];
// }
// #else
// void ApplePlatformUtils::init_sparkle() {}
// #endif

// #if defined(Q_OS_IOS) || defined(Q_OS_MACOS)

// void ApplePlatformUtils::authenticateWithBiometric(
//     const QString &reason, std::function<void(bool, const char *)> callback)
//     {
//   LAContext *context = [[LAContext alloc] init];
//   NSError *error = nil;
//   NSString *nsReason = reason.toNSString();
//   if ([context
//   canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics
//                            error:&error]) {
//     [context evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics
//             localizedReason:nsReason
//                       reply:^(BOOL success, NSError *_Nullable authError) {
//                         (void)context;
//                         dispatch_async(dispatch_get_main_queue(), ^{
//                           if (!callback)
//                             return;
//                           if (success) {
//                             callback(true, "");
//                             return;
//                           }
//                           NSString *errorString =
//                               authError ? authError.localizedDescription
//                                         : @"Unknown error";
//                           switch (authError.code) {
//                           case LAErrorUserCancel:
//                             errorString = @"User cancelled";
//                             break;
//                           case LAErrorUserFallback:
//                             requestPasscodeFallback(callback);
//                             return;
//                           case LAErrorAuthenticationFailed:
//                             errorString = @"Authentication failed";
//                             break;
//                           case LAErrorSystemCancel:
//                             errorString = @"System cancelled";
//                             break;
//                           case LAErrorAppCancel:
//                             errorString = @"App cancelled authentication";
//                             break;
//                           case LAErrorBiometryLockout:
//                             errorString =
//                                 @"Biometry locked out; requires passcode";
//                             break;
//                           default:
//                             break;
//                           }
//                           callback(false, errorString.UTF8String);
//                         });
//                       }];
//   } else {
//     if (callback) {
//       dispatch_async(dispatch_get_main_queue(), ^{
//         callback(false, error.localizedDescription.UTF8String);
//       });
//     }
//   }
// }

// void ApplePlatformUtils::requestPasscodeFallback(
//     std::function<void(bool, const char *)> callback) {
//   LAContext *context = [[LAContext alloc] init];
//   NSError *error = nil;
//   if ([context canEvaluatePolicy:LAPolicyDeviceOwnerAuthentication
//                            error:&error]) {
//     [context evaluatePolicy:LAPolicyDeviceOwnerAuthentication
//             localizedReason:@"Please authenticate to continue."
//                       reply:^(BOOL success, NSError *_Nullable authError) {
//                         (void)context;
//                         dispatch_async(dispatch_get_main_queue(), ^{
//                           if (!callback)
//                             return;
//                           if (success) {
//                             callback(true, "");
//                           } else {
//                             NSString *msg = authError
//                                                 ?
//                                                 authError.localizedDescription
//                                                 : @"Unknown error";
//                             callback(false, msg.UTF8String);
//                           }
//                         });
//                       }];
//   } else {
//     if (callback) {
//       dispatch_async(dispatch_get_main_queue(), ^{
//         callback(false, error.localizedDescription.UTF8String);
//       });
//     }
//   }
// }

// void ApplePlatformUtils::triggerBiometric(const QString &reason) {
//   QString r =
//       reason.isEmpty() ? QStringLiteral("Authenticate to continue") : reason;
//   QPointer<ApplePlatformUtils> safeSelf = this;
//   authenticateWithBiometric(
//       r, [safeSelf](bool success, const char *errorMessage) {
//         qDebug() << "biometric callback, success:" << success
//                  << "error:" << errorMessage;
//         if (safeSelf)
//           emit safeSelf->biometricAuthResult(success);
//       });
// }

// bool ApplePlatformUtils::isBiometricAvailable() {
//   LAContext *context = [[LAContext alloc] init];
//   NSError *error = nil;
//   BOOL canEvaluate =
//       [context
//       canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics
//                            error:&error];
//   if (!canEvaluate) {
//     if (error)
//       qDebug() << "isBiometricAvailable:"
//                << error.localizedDescription.UTF8String;
//     return false;
//   }
//   return context.biometryType == LABiometryTypeFaceID ||
//          context.biometryType == LABiometryTypeTouchID;
// }

// #endif // Q_OS_IOS || Q_OS_MACOS

#ifdef Q_OS_IOS

void ApplePlatformUtils::vibrate() {
  if (@available(iOS 10.0, *)) {
    UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc]
        initWithStyle:UIImpactFeedbackStyleMedium];
    [generator prepare];
    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(200 * NSEC_PER_MSEC)),
        dispatch_get_main_queue(), ^{
          [generator impactOccurred];
        });
  }
}

QString ApplePlatformUtils::model() {
  struct utsname systemInfo;
  uname(&systemInfo);
  return QString::fromUtf8(systemInfo.machine);
}

#endif // Q_OS_IOS
