#include "KeychainStore.h"
#import <Foundation/Foundation.h>
#import <Security/Security.h>

namespace {
// MUST match KeychainBridge.swift in the extension.
NSString *const kService = @"com.rodon.vpn";
NSString *const kAccount = @"wg-private-key";
NSString *const kAccessGroup = @"H8GLL2MY9E.com.rodon.shared";

NSMutableDictionary *baseQuery() {
  NSMutableDictionary *q = [NSMutableDictionary dictionary];
  q[(__bridge id)kSecClass] = (__bridge id)kSecClassGenericPassword;
  q[(__bridge id)kSecAttrService] = kService;
  q[(__bridge id)kSecAttrAccount] = kAccount;
  q[(__bridge id)kSecAttrAccessGroup] = kAccessGroup;
  return q;
}
}

namespace KeychainStore {

bool savePrivateKey(const QString &keyBase64) {
  const QByteArray utf8 = keyBase64.toUtf8();
  NSData *data = [NSData dataWithBytes:utf8.constData() length:utf8.size()];

  SecItemDelete((__bridge CFDictionaryRef)baseQuery()); // overwrite

  NSMutableDictionary *q = baseQuery();
  q[(__bridge id)kSecValueData] = data;
  q[(__bridge id)kSecAttrAccessible] =
      (__bridge id)kSecAttrAccessibleAfterFirstUnlock;

  OSStatus st = SecItemAdd((__bridge CFDictionaryRef)q, NULL);
  return st == errSecSuccess;
}

QString loadPrivateKey() {
  NSMutableDictionary *q = baseQuery();
  q[(__bridge id)kSecReturnData] = @YES;
  q[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;

  CFTypeRef result = NULL;
  OSStatus st = SecItemCopyMatching((__bridge CFDictionaryRef)q, &result);
  if (st != errSecSuccess || result == NULL) {
    return QString();
  }
  NSData *data = (__bridge_transfer NSData *)result;
  return QString::fromUtf8(reinterpret_cast<const char *>(data.bytes),
                           static_cast<int>(data.length));
}

bool clearPrivateKey() {
  OSStatus st = SecItemDelete((__bridge CFDictionaryRef)baseQuery());
  return st == errSecSuccess || st == errSecItemNotFound;
}

} // namespace KeychainStore
