#pragma once
#include <NetworkManagerController.h>
#include <QDebug>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QObject>

#include "Structs.h"

class AuthController : public QObject {
  Q_OBJECT

  QUrl createUrl = QUrl(QString("%1/account/create").arg(RODON_URL));
  QUrl sighInUrl = QUrl(QString("%1/account/signin").arg(RODON_URL));
  QUrl registerDeviceUrl = QUrl(QString("%1/devices/register").arg(RODON_URL));
  QUrl aboutMeUrl = QUrl(QString("%1/account/me").arg(RODON_URL));

  NetworkManager *networkManager;
  QString token;

public:
  explicit AuthController(QObject *parent);
  QString getToken() const { return token; };

  NetworkManager *getNetworkManager() const;

public slots:
  void registration(const QString &reserveEmail);
  void auth(const QString &code);
  void registerDevice(const QString &body);
  void aboutMe();

signals:
  void accountCode(const QString &code);
  void authorized();
  void errorAuthorization();
  void updateDeviceList();
  void myAccount(AccountMe &);
};
