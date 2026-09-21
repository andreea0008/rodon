#include "KeychainStore.h"
#include <QSettings>

// TEMP: plain QSettings for non-Apple platforms. Replace with qtkeychain
// (Android Keystore / Windows Credential Store) when tackling those platforms.
namespace KeychainStore {
bool savePrivateKey(const QString &k) {
  QSettings().setValue(QStringLiteral("wg/private_key"), k);
  return true;
}
QString loadPrivateKey() {
  return QSettings().value(QStringLiteral("wg/private_key")).toString();
}
bool clearPrivateKey() {
  QSettings().remove(QStringLiteral("wg/private_key"));
  return true;
}
} // namespace KeychainStore
