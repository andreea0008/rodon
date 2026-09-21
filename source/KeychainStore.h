#pragma once
#include <QString>

// Stores the WireGuard private key in the system Keychain with a shared
// access group, so the Network Extension (separate process) can read it.
// Implemented in KeychainStore_apple.mm (iOS/macOS).
namespace KeychainStore {
bool savePrivateKey(const QString &keyBase64);
QString loadPrivateKey();
bool clearPrivateKey();
} // namespace KeychainStore
