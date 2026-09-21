#pragma once

#include "NetworkManagerController.h"
#include "Structs.h"
#include <QAbstractItemModel>
#include <QObject>

class LocationController : public QAbstractListModel {
  Q_OBJECT

  Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
  Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
  Q_PROPERTY(QString currentLocationCode READ currentLocationCode WRITE
                 setCurrentLocationCode NOTIFY currentLocationCodeChanged)
  Q_PROPERTY(QString currentLocationCountry READ currentLocationCountry WRITE
                 setCurrentLocationCountry NOTIFY currentLocationCountryChanged)
  Q_PROPERTY(QString currentLocationId READ currentLocationId WRITE
                 setCurrentLocationId NOTIFY currentLocationIdChanged)

public:
  enum Roles {
    Id,
    CountryCode,
    CountryName,
    City,
    Tier,
    LoadFactor,
    Available
  };
  Q_ENUM(Roles)

  explicit LocationController(NetworkManager *nm, QObject *parent = nullptr);
  int rowCount(const QModelIndex &parent = QModelIndex()) const override;
  QVariant data(const QModelIndex &index, int role) const override;
  QHash<int, QByteArray> roleNames() const override;
  Location currentLocation() const { return m_locations[currentLocationIndex]; }
  bool loading() const;
  void setLoading(bool loading);
  void setToken(const QString &token) { m_token = token; }

  QString currentLocationCode() const;
  void setCurrentLocationCode(const QString &newCurrentLocationCode);

  QString currentLocationCountry() const;
  void setCurrentLocationCountry(const QString &newCurrentLocationCountry);

  QString currentLocationId() const;
  void setCurrentLocationId(const QString &newCurrentLocationId);

public slots:
  void fetchLocations();
  void setCurrentLocationByIndex(const int &index);
  void randomLocation();
  void filterByName(const QString &partNameCountry);
  bool possibleConnectToLocationByCode(const QString &code);
  int indexLocationByCode(const QString &code);

signals:
  void loadingChanged();
  void errorOccurred(const QString &message);
  void countChanged();
  void locationChanged();
  void currentLocationCodeChanged();
  void currentLocationCountryChanged();
  void locationIndexChanged(const int &index);
  void currentLocationIdChanged();

protected:
  void handleReply(QNetworkReply *reply,
                   std::function<void(const QJsonDocument &)> onSuccess);

private:
  QList<Location> m_locations, m_cachedLocation;
  NetworkManager *networkManager = nullptr;
  QString m_token;
  QString m_currentLocationCode;
  QString m_currentLocationCountry;
  QString m_currentLocationId;
  int currentLocationIndex = -1;
  int m_count;
  bool m_loading;
};
