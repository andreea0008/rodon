#pragma once
#include <QAbstractListModel>
#include <QDateTime>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QSettings>
#include <QSysInfo>
#include <QUuid>

#include "NetworkManagerController.h"
#include "Structs.h"

class DeviceController : public QAbstractListModel {
  Q_OBJECT
  Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
  Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
  Q_PROPERTY(int maxDevices READ maxDevices CONSTANT)
  Q_PROPERTY(QString currentDeviceId READ currentDeviceId CONSTANT)

public:
  enum Roles {
    IdRole = Qt::UserRole + 1,
    DeviceIdRole,
    NameRole,
    PlatformRole,
    CreatedAtRole,
    LastSeenAtRole,
    IsCurrentRole,
  };
  Q_ENUM(Roles)

  explicit DeviceController(NetworkManager *nm, QObject *parent = nullptr);

  int rowCount(const QModelIndex &parent = QModelIndex()) const override;
  QVariant data(const QModelIndex &index, int role) const override;
  QHash<int, QByteArray> roleNames() const override;

  bool loading() const { return m_loading; }
  int maxDevices() const { return 5; }
  QString currentDeviceId() const { return m_currentDeviceId; }

public slots:
  void fetchDevices();
  void registerCurrentDevice();
  void heartbeat();
  void removeDevice(const QString &deviceId);
  void removeOtherDevices();

signals:
  void loadingChanged();
  void countChanged();
  void errorOccurred(const QString &message);
  void deviceRegistered(const QString &evictedId);
  void deviceRemoved(const QString &deviceId);

private:
  QNetworkRequest makeRequest(const QString &path) const;
  void handleReply(QNetworkReply *reply,
                   std::function<void(const QJsonDocument &)> onSuccess);
  void setLoading(bool loading);
  void ensureDeviceId();
  static QString platformString();
  static QString deviceName();

  NetworkManager *m_networkManager;
  QList<Device> m_devices;
  QString m_token;
  QString m_currentDeviceId;
  bool m_loading = false;
};
