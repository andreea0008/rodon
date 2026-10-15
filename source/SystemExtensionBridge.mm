#include "SystemExtensionBridge.h"
#import <Foundation/Foundation.h>
#import <SystemExtensions/SystemExtensions.h>

@interface RodONSysExtDelegate : NSObject <OSSystemExtensionRequestDelegate>
@end

@implementation RodONSysExtDelegate

- (OSSystemExtensionReplacementAction)
                        request:(OSSystemExtensionRequest *)request
    actionForReplacingExtension:(OSSystemExtensionProperties *)existing
                  withExtension:(OSSystemExtensionProperties *)ext {
  NSLog(@"SystemExtension: replacing existing");
  return OSSystemExtensionReplacementActionReplace;
}

- (void)requestNeedsUserApproval:(OSSystemExtensionRequest *)request {
  NSLog(@"SystemExtension: needs user approval in System Settings");
}

- (void)request:(OSSystemExtensionRequest *)request
    didFinishWithResult:(OSSystemExtensionRequestResult)result {
  NSLog(@"SystemExtension: finished — %ld", (long)result);
}

- (void)request:(OSSystemExtensionRequest *)request
    didFailWithError:(NSError *)error {
  NSLog(@"SystemExtension: failed — %@", error.localizedDescription);
}

@end

static RodONSysExtDelegate *g_delegate = nil;

void activateSystemExtension(const char *bundleId) {
  if (!g_delegate) {
    g_delegate = [[RodONSysExtDelegate alloc] init];
  }
  NSString *nsBundleId = [NSString stringWithUTF8String:bundleId];
  OSSystemExtensionRequest *request = [OSSystemExtensionRequest
      activationRequestForExtension:nsBundleId
                              queue:dispatch_get_main_queue()];
  request.delegate = g_delegate;
  [[OSSystemExtensionManager sharedManager] submitRequest:request];
}

void deactivateSystemExtension(const char *bundleId) {
  static RodONSysExtDelegate *delegate = [RodONSysExtDelegate new];
  OSSystemExtensionRequest *req = [OSSystemExtensionRequest
      deactivationRequestForExtension:@(bundleId)
                                queue:dispatch_get_main_queue()];
  req.delegate = delegate;
  [[OSSystemExtensionManager sharedManager] submitRequest:req];
  NSLog(@">>> SYSEXT: deactivation request submitted for %s", bundleId);
}
