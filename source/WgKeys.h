#pragma once
#include <QByteArray>
#include <QString>

struct WgKeyPair {
  QString privateKey;
  QString publicKey;
};

namespace WgKeys {
WgKeyPair generate();
QString publicFromPrivate(const QString &privateKeyBase64);
} // namespace WgKeys
