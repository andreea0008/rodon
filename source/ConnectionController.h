#pragma once

#include <NetworkManagerController.h>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QObject>
#include <QTimer>
#include <qqml.h>

#if defined(Q_OS_IOS) || defined(Q_OS_MACOS)
#include "ios/TunnelBridge.h"
#endif

class ConnectionController : public QObject {
  Q_OBJECT
  QML_ELEMENT

  Q_PROPERTY(Status status READ status NOTIFY statusChanged)
  Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)
  Q_PROPERTY(
      QString serverEndpoint READ serverEndpoint NOTIFY peerConfigChanged)
  Q_PROPERTY(QString assignedIp READ assignedIp NOTIFY peerConfigChanged)
  Q_PROPERTY(QString currentIp READ currentIp NOTIFY currentIpChanged)
  Q_PROPERTY(
      QString currentCountry READ currentCountry NOTIFY currentCountryChanged)
  Q_PROPERTY(QString currentCode READ currentCode NOTIFY currentCodeChanged)
  Q_PROPERTY(QString currentPing READ currentPing WRITE setCurrentPing NOTIFY
                 currentPingChanged FINAL)
  Q_PROPERTY(QString currentCity READ currentCity NOTIFY currentCityChanged)
  Q_PROPERTY(bool isOnline READ isOnline WRITE setIsOnline NOTIFY
                 isOnlineChanged FINAL)

public:
  enum Status {
    NotConnected = 1,
    Connecting,
    Connected,
    Disconnecting,
    Error,
    Offline
  };

  Q_ENUM(Status);

  ConnectionController(NetworkManager *nm, QObject *parent = nullptr);
  ~ConnectionController() {}

  Status status() const;
  QString lastError() const;
  QString serverEndpoint() const;
  QString assignedIp() const;
  QString currentIp() const;
  QString currentCountry() const;
  QString currentCode() const;
  QString currentPing() const;
  void setCurrentPing(const QString &newCurrentPing);
  QString currentCity() const;
  bool isOnline() const;
  void setIsOnline(bool newIsOnline);

public slots:
  void connectToLocation(const QString &locationId, const QString &deviceId);
  void disconnect(const QString &deviceId);
  void checkInternet();
  void stopTunnel();
  void refreshStatus();

signals:
  void statusChanged();
  void lastErrorChanged();
  void peerConfigChanged();
  void currentIpChanged();
  void currentCountryChanged();
  void currentCodeChanged();
  void currentPingChanged();
  void currentCityChanged();
  void isOnlineChanged();

protected:
  QNetworkRequest makeRequest(const QString &endpoint);
  void handleReply(QNetworkReply *reply,
                   std::function<void(const QJsonDocument &)> onSuccess);
  void setError(const QString &error);
  void setStatus(Status s);
  void updateIpAndCountry();
  void ping();

private:
  NetworkManager *networkManager;
  QTimer *internetCheckTimer;
  Status m_status = Status::NotConnected;
  QString m_lastError;
  QString m_serverEndpoint;
  QString m_assignedIp;
  QString m_serverPublicKey; // needed by the tunnel later
  QString m_dns;
  QString m_currentIp;
  QString m_currentCountry;
  QString m_currentCode;
  QString m_currentPing;
  QString m_currentCity;
  bool m_isOnline = false;

#if defined(Q_OS_IOS) || defined(Q_OS_MACOS)
  TunnelBridge *m_tunnel;
#endif
};
