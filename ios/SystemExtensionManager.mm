#include "SystemExtensionManager.h"

#include <QCoreApplication>
#include <QDebug>
#include <QTimer>

#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#import <SystemExtensions/SystemExtensions.h>

static NSString *const kRodONExtensionId = @"com.rodon.vpn.app.tunnel";

@interface RodONSysExtManagerDelegate
    : NSObject <OSSystemExtensionRequestDelegate>
@property(nonatomic, assign) SystemExtensionManager *owner;
@property(nonatomic, assign) BOOL deactivating;
@end

@implementation RodONSysExtManagerDelegate

- (OSSystemExtensionReplacementAction)
                        request:(OSSystemExtensionRequest *)request
    actionForReplacingExtension:(OSSystemExtensionProperties *)existing
                  withExtension:(OSSystemExtensionProperties *)ext {
  NSLog(@"SysExt: replacing %@ (%@) with %@ (%@)", existing.bundleShortVersion,
        existing.bundleVersion, ext.bundleShortVersion, ext.bundleVersion);
  return OSSystemExtensionReplacementActionReplace;
}

- (void)requestNeedsUserApproval:(OSSystemExtensionRequest *)request {
  NSLog(@"SysExt: needs user approval");
  if (self.owner)
    self.owner->onNeedsApproval();
}

- (void)request:(OSSystemExtensionRequest *)request
    didFinishWithResult:(OSSystemExtensionRequestResult)result {
  NSLog(@"SysExt: finished, result=%ld (deactivating=%d)", (long)result,
        self.deactivating);
  if (!self.owner)
    return;
  if (self.deactivating) {
    self.deactivating = NO;
    self.owner->onDeactivated();
  } else {
    self.owner->onActivated(result ==
                            OSSystemExtensionRequestWillCompleteAfterReboot);
  }
}

- (void)request:(OSSystemExtensionRequest *)request
    didFailWithError:(NSError *)error {
  NSLog(@"SysExt: failed — %@ (code %ld)", error.localizedDescription,
        (long)error.code);
  self.deactivating = NO;
  if (self.owner)
    self.owner->onFailed(QString::fromNSString(error.localizedDescription),
                         (long)error.code);
}

@end

static RodONSysExtManagerDelegate *g_sysExtDelegate = nil;

SystemExtensionManager *SystemExtensionManager::instance() {
  static SystemExtensionManager *s = new SystemExtensionManager();
  return s;
}

SystemExtensionManager::SystemExtensionManager(QObject *parent)
    : QObject(parent) {
  g_sysExtDelegate = [[RodONSysExtManagerDelegate alloc] init];
  g_sysExtDelegate.owner = this;
}

void SystemExtensionManager::setState(State s, const QString &error) {
  const bool becameReady = (s == Ready && m_state != Ready);
  m_state = s;
  m_error = error;
  emit stateChanged();
  if (becameReady)
    emit ready();
}

bool SystemExtensionManager::isInApplications() const {
  NSString *path = NSBundle.mainBundle.bundlePath;
  return [path hasPrefix:@"/Applications/"];
}

void SystemExtensionManager::activate() {
  // sysextd приймає system extension тільки від апки з /Applications.
  if (!isInApplications()) {
    qDebug() << "SysExt: app is not in /Applications:"
             << QString::fromNSString(NSBundle.mainBundle.bundlePath);
    setState(NotInApplications);
    return;
  }
  if (m_state == Ready) {
    emit ready();
    return;
  }
  if (m_requestInFlight) {
    qDebug() << "SysExt: activation already in progress";
    return;
  }
  m_requestInFlight = true;
  g_sysExtDelegate.deactivating = NO;
  setState(Activating);

  OSSystemExtensionRequest *req = [OSSystemExtensionRequest
      activationRequestForExtension:kRodONExtensionId
                              queue:dispatch_get_main_queue()];
  req.delegate = g_sysExtDelegate;
  [[OSSystemExtensionManager sharedManager] submitRequest:req];
  qDebug() << "SysExt: activation request submitted";
}

void SystemExtensionManager::deactivate() {
  if (m_requestInFlight) {
    qDebug() << "SysExt: request in progress, deactivate skipped";
    return;
  }
  m_requestInFlight = true;
  g_sysExtDelegate.deactivating = YES;

  OSSystemExtensionRequest *req = [OSSystemExtensionRequest
      deactivationRequestForExtension:kRodONExtensionId
                                queue:dispatch_get_main_queue()];
  req.delegate = g_sysExtDelegate;
  [[OSSystemExtensionManager sharedManager] submitRequest:req];
  qDebug() << "SysExt: deactivation request submitted";
}

void SystemExtensionManager::openSettings() {
  NSURL *url = [NSURL
      URLWithString:
          @"x-apple.systempreferences:com.apple.LoginItems-Settings.extension"];
  if (![[NSWorkspace sharedWorkspace] openURL:url]) {
    // запасний варіант — Privacy & Security
    [[NSWorkspace sharedWorkspace]
        openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple."
                                     @"preference.security"]];
  }
}

void SystemExtensionManager::moveToApplications() {
  NSFileManager *fm = NSFileManager.defaultManager;
  NSString *src = NSBundle.mainBundle.bundlePath;
  NSString *dst =
      [@"/Applications" stringByAppendingPathComponent:src.lastPathComponent];
  NSError *err = nil;

  // Стару копію — у Кошик (не rm), щоб її можна було відновити.
  if ([fm fileExistsAtPath:dst]) {
    if (![fm trashItemAtURL:[NSURL fileURLWithPath:dst]
            resultingItemURL:nil
                       error:&err]) {
      setState(Failed, QString::fromNSString(err.localizedDescription));
      return;
    }
  }

  if (![fm copyItemAtPath:src toPath:dst error:&err]) {
    setState(Failed, QString::fromNSString(err.localizedDescription));
    return;
  }

  qDebug() << "SysExt: copied to" << QString::fromNSString(dst)
           << "— relaunching";

  NSWorkspaceOpenConfiguration *cfg =
      [NSWorkspaceOpenConfiguration configuration];
  cfg.createsNewApplicationInstance = YES;
  [[NSWorkspace sharedWorkspace]
      openApplicationAtURL:[NSURL fileURLWithPath:dst]
             configuration:cfg
         completionHandler:^(NSRunningApplication *app, NSError *openErr) {
           dispatch_async(dispatch_get_main_queue(), ^{
             if (openErr) {
               setState(Failed,
                        QString::fromNSString(openErr.localizedDescription));
               return;
             }
             QCoreApplication::quit();
           });
         }];
}

void SystemExtensionManager::onNeedsApproval() { setState(NeedsApproval); }

void SystemExtensionManager::onActivated(bool needsReboot) {
  m_requestInFlight = false;
  setState(needsReboot ? RebootRequired : Ready);
}

void SystemExtensionManager::onDeactivated() {
  m_requestInFlight = false;
  setState(Unknown);
}

void SystemExtensionManager::onFailed(const QString &message, long code) {
  m_requestInFlight = false;
  if (code == 11 || code == 12) {
    setState(Unknown);
    return;
  }
  // 4 = extensionNotFound: бандл не з /Applications або пошкоджений
  if (code == 4) {
    if (!isInApplications()) {
      setState(NotInApplications);
    } else {
      setState(Failed, tr("The VPN component is missing from the app. "
                          "Please reinstall RodON from the latest DMG."));
    }
    return;
  }
  setState(Failed, message);
}