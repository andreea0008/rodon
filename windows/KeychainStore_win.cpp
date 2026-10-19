// Windows-реалізація KeychainStore: приватний ключ WireGuard зберігається
// в Windows Credential Manager (Диспетчер облікових даних), прив'язано до
// поточного користувача на цьому комп'ютері (не синхронізується між ПК).
#include "KeychainStore.h"

#include <windows.h>
#include <wincred.h>

namespace {
const wchar_t *kTarget = L"RodON/wg-private-key";
const wchar_t *kUser = L"RodON";
} // namespace

namespace KeychainStore {

bool savePrivateKey(const QString &keyBase64) {
  const QByteArray blob = keyBase64.toUtf8();

  CREDENTIALW cred{};
  cred.Type = CRED_TYPE_GENERIC;
  cred.TargetName = const_cast<LPWSTR>(kTarget);
  cred.UserName = const_cast<LPWSTR>(kUser);
  cred.CredentialBlobSize = static_cast<DWORD>(blob.size());
  cred.CredentialBlob =
      reinterpret_cast<LPBYTE>(const_cast<char *>(blob.constData()));
  cred.Persist = CRED_PERSIST_LOCAL_MACHINE; // лише цей ПК, без роумінгу

  return CredWriteW(&cred, 0) == TRUE; // перезаписує, якщо вже існує
}

QString loadPrivateKey() {
  PCREDENTIALW cred = nullptr;
  if (!CredReadW(kTarget, CRED_TYPE_GENERIC, 0, &cred) || !cred)
    return QString();

  const QString key = QString::fromUtf8(
      reinterpret_cast<const char *>(cred->CredentialBlob),
      static_cast<int>(cred->CredentialBlobSize));
  CredFree(cred);
  return key;
}

bool clearPrivateKey() {
  if (CredDeleteW(kTarget, CRED_TYPE_GENERIC, 0))
    return true;
  return GetLastError() == ERROR_NOT_FOUND;
}

} // namespace KeychainStore
