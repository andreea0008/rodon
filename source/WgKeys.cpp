#include "WgKeys.h"
#include <sodium.h>

namespace {
void clamp(unsigned char *key) {
  key[0] &= 248;
  key[31] &= 127;
  key[31] |= 64;
}
} // namespace

WgKeyPair WgKeys::generate() {
  if (sodium_init() < 0) {
    return {};
  }

  unsigned char priv[32];
  unsigned char pub[32];

  randombytes_buf(priv, sizeof priv);
  clamp(priv);

  crypto_scalarmult_base(pub, priv);

  WgKeyPair kp;
  kp.privateKey = QString::fromLatin1(
      QByteArray(reinterpret_cast<char *>(priv), 32).toBase64());
  kp.publicKey = QString::fromLatin1(
      QByteArray(reinterpret_cast<char *>(pub), 32).toBase64());

  sodium_memzero(priv, sizeof priv);
  sodium_memzero(pub, sizeof pub);

  return kp;
}

QString WgKeys::publicFromPrivate(const QString &privateKeyBase64) {
  if (sodium_init() < 0)
    return {};

  const QByteArray raw = QByteArray::fromBase64(privateKeyBase64.toLatin1());
  if (raw.size() != 32)
    return {};

  unsigned char priv[32];
  memcpy(priv, raw.constData(), 32);

  unsigned char pub[32];
  crypto_scalarmult_base(pub, priv);

  const QString result = QString::fromLatin1(
      QByteArray(reinterpret_cast<char *>(pub), 32).toBase64());

  sodium_memzero(priv, sizeof priv);
  sodium_memzero(pub, sizeof pub);
  return result;
}
