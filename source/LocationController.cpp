#include "LocationController.h"
#include <QRandomGenerator>
#include <QtCore/qjsonarray.h>

LocationController::LocationController(NetworkManager *nm, QObject *parent)
    : QAbstractListModel(parent) {
  networkManager = nm;
}

int LocationController::rowCount(const QModelIndex &parent) const {
  return parent.isValid() ? 0 : m_locations.size();
}

QVariant LocationController::data(const QModelIndex &index, int role) const {
  if (!index.isValid() || index.row() < 0 || index.row() >= m_locations.size())
    return {};

  const Location &l = m_locations.at(index.row());
  switch (role) {
  case Id:
    return l.id;
  case CountryCode:
    return l.countryCode;
  case CountryName:
    return l.countryName;
  case City:
    return l.city;
  case Tier:
    return l.tier;
  case LoadFactor:
    return l.loadFactor;
  case Available:
    return l.available;
  default:
    return {};
  };
}

QHash<int, QByteArray> LocationController::roleNames() const {
  return {
      {Id, "id"},
      {CountryCode, "countryCode"},
      {CountryName, "countryName"},
      {City, "city"},
      {Tier, "tier"},
      {LoadFactor, "loadFactor"},
      {Available, "available"},
  };
}

void LocationController::fetchLocations() {
  setLoading(true);
  if (!networkManager) {
    qWarning() << "LocationController: QNetworkAccessManager is null";
    return;
  }

  QNetworkRequest request(
      QUrl(QString("%1%2").arg(RODON_URL).arg("/locations")));
  request.setHeader(QNetworkRequest::ContentTypeHeader,
                    QStringLiteral("application/json"));
  request.setRawHeader("Authorization",
                       "Bearer " + networkManager->getToken().toUtf8());
  QNetworkReply *reply = networkManager->get(request);

  handleReply(reply, [this](const QJsonDocument &doc) {
    qDebug() << "location_doc" << doc;
    const QJsonArray arr = doc.array();

    beginResetModel();
    m_locations.clear();
    m_locations.reserve(arr.size());

    for (const QJsonValue &v : arr) {
      const QJsonObject o = v.toObject();
      Location l(o);
      m_locations.append(l);
    }
    m_cachedLocation = m_locations;

    endResetModel();
    emit countChanged();
    qDebug() << "Location count: " << m_locations.size();
  });
}

void LocationController::setCurrentLocationByIndex(const int &index) {
  currentLocationIndex = index;
  const auto currentLocation = m_locations[index];
  setCurrentLocationCode(currentLocation.countryCode);
  setCurrentLocationCountry(currentLocation.countryName);
  setCurrentLocationId(currentLocation.id);
  emit locationChanged();
}

void LocationController::randomLocation() {
  if (m_locations.size() > 0) {
    int value = QRandomGenerator::global()->bounded(m_locations.size());
    setCurrentLocationByIndex(value);
    emit locationIndexChanged(value);
  } else {
    qDebug() << "Count locations is empty";
  }
}

void LocationController::filterByName(const QString &partNameCountry) {
  beginResetModel();

  if (partNameCountry.isEmpty()) {
    m_locations = m_cachedLocation;
  } else {
    m_locations.clear();
    for (const auto &loc : m_cachedLocation) {
      if (loc.countryName.contains(partNameCountry, Qt::CaseInsensitive)) {
        m_locations.push_back(loc);
      }
    }
  }

  endResetModel();
  emit countChanged();
}

bool LocationController::possibleConnectToLocationByCode(const QString &code) {
  auto it = std::find_if(m_cachedLocation.begin(), m_cachedLocation.end(),
                         [&code](const Location &l) {
                           return l.countryCode.compare(
                                      code, Qt::CaseInsensitive) == 0;
                         });
  return it != m_cachedLocation.end() && it->available;
}

int LocationController::indexLocationByCode(const QString &code) {
  int result = -1;
  for (int i = 0; i < m_cachedLocation.size(); i++) {
    if (m_cachedLocation[i].countryCode == code) {
      result = i;
    }
  }
  return result;
}

void LocationController::handleReply(
    QNetworkReply *reply,
    std::function<void(const QJsonDocument &)> onSuccess) {
  connect(reply, &QNetworkReply::finished, this, [this, reply, onSuccess]() {
    reply->deleteLater();
    setLoading(false);

    const QByteArray body = reply->readAll();

    if (reply->error() != QNetworkReply::NoError) {
      const QJsonObject obj = QJsonDocument::fromJson(body).object();
      const QString msg =
          obj.value(QStringLiteral("error")).toString(reply->errorString());
      qWarning() << "LocationController error:" << msg << body;
      emit errorOccurred(msg);
      return;
    }

    onSuccess(QJsonDocument::fromJson(body));
  });
}

bool LocationController::loading() const { return m_loading; }

void LocationController::setLoading(bool loading) {
  if (m_loading == loading)
    return;
  m_loading = loading;
  emit loadingChanged();
}

QString LocationController::currentLocationCode() const {
  return m_currentLocationCode;
}

void LocationController::setCurrentLocationCode(
    const QString &newCurrentLocationCode) {
  if (m_currentLocationCode == newCurrentLocationCode)
    return;
  m_currentLocationCode = newCurrentLocationCode;
  emit currentLocationCodeChanged();
}

QString LocationController::currentLocationCountry() const {
  return m_currentLocationCountry;
}

void LocationController::setCurrentLocationCountry(
    const QString &newCurrentLocationCountry) {
  if (m_currentLocationCountry == newCurrentLocationCountry)
    return;
  m_currentLocationCountry = newCurrentLocationCountry;
  emit currentLocationCountryChanged();
}

QString LocationController::currentLocationId() const {
  return m_currentLocationId;
}

void LocationController::setCurrentLocationId(
    const QString &newCurrentLocationId) {
  if (m_currentLocationId == newCurrentLocationId)
    return;
  m_currentLocationId = newCurrentLocationId;
  emit currentLocationIdChanged();
}
