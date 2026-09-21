#include "devicecontroller.h"

DeviceController::DeviceController(NetworkManager *nm, QObject *parent)
    : QAbstractListModel(parent) {
  m_networkManager = nm;
  // ensureDeviceId();
}

int DeviceController::rowCount(const QModelIndex &parent) const {
  if (parent.isValid())
    return 0;
  return m_devices.size();
}

QVariant DeviceController::data(const QModelIndex &index, int role) const {
  if (!index.isValid() || index.row() < 0 || index.row() >= m_devices.size())
    return {};

  const Device &d = m_devices.at(index.row());

  switch (role) {
  case IdRole:
    return d.id;
  case DeviceIdRole:
    return d.device_id;
  case NameRole:
    return d.name;
  case PlatformRole:
    return d.platform;
  case CreatedAtRole:
    return d.createdAt;
  case LastSeenAtRole:
    return d.lastSeenAt;
  case IsCurrentRole:
    return d.device_id == m_currentDeviceId;
  default:
    return {};
  }
}

QHash<int, QByteArray> DeviceController::roleNames() const {
  return {
      {IdRole, "id"},
      {DeviceIdRole, "deviceId"},
      {NameRole, "name"},
      {PlatformRole, "platform"},
      {CreatedAtRole, "createdAt"},
      {LastSeenAtRole, "lastSeenAt"},
      {IsCurrentRole, "isCurrent"},
  };
}

void DeviceController::ensureDeviceId() {
  QSettings settings;
  m_currentDeviceId = settings.value(QStringLiteral("device/id")).toString();

  if (m_currentDeviceId.isEmpty()) {
    m_currentDeviceId = QUuid::createUuid().toString(QUuid::WithoutBraces);
    settings.setValue(QStringLiteral("device/id"), m_currentDeviceId);
  }
}

QString DeviceController::platformString() {
  return QSysInfo::productType() + QLatin1Char(' ') +
         QSysInfo::productVersion();
}

QString DeviceController::deviceName() { return QSysInfo::machineHostName(); }

QNetworkRequest DeviceController::makeRequest(const QString &path) const {
  QNetworkRequest req(QUrl(RODON_URL + path));
  req.setHeader(QNetworkRequest::ContentTypeHeader,
                QStringLiteral("application/json"));
  req.setRawHeader("Authorization",
                   "Bearer " + m_networkManager->getToken().toUtf8());
  return req;
}

void DeviceController::setLoading(bool loading) {
  if (m_loading == loading)
    return;
  m_loading = loading;
  emit loadingChanged();
}

void DeviceController::handleReply(
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
      qWarning() << "DeviceController error:" << msg << body;
      emit errorOccurred(msg);
      return;
    }

    onSuccess(QJsonDocument::fromJson(body));
  });
}

void DeviceController::fetchDevices() {
  setLoading(true);
  if (!m_networkManager) {
    qWarning() << "DeviceController: QNetworkAccessManager is null";
    return;
  }
  qDebug() << m_token;
  QNetworkRequest request = makeRequest(QStringLiteral("/devices"));
  QNetworkReply *reply = m_networkManager->get(request);

  handleReply(reply, [this](const QJsonDocument &doc) {
    const QJsonArray arr = doc.array();

    beginResetModel();
    m_devices.clear();
    m_devices.reserve(arr.size());

    for (const QJsonValue &v : arr) {
      const QJsonObject o = v.toObject();
      Device d;
      d.id = o.value(QStringLiteral("id")).toString();
      d.device_id = o.value(QStringLiteral("device_id")).toString();
      d.name = o.value(QStringLiteral("name")).toString();
      d.platform = o.value(QStringLiteral("platform")).toString();
      d.createdAt = QDateTime::fromString(
          o.value(QStringLiteral("created_at")).toString(), Qt::ISODateWithMs);
      d.lastSeenAt = QDateTime::fromString(
          o.value(QStringLiteral("last_seen_at")).toString(),
          Qt::ISODateWithMs);
      m_devices.append(d);
    }

    endResetModel();
    emit countChanged();
  });
}

void DeviceController::registerCurrentDevice() {
  setLoading(true);

  QJsonObject body;
  body[QStringLiteral("device_id")] = m_currentDeviceId;
  body[QStringLiteral("name")] = deviceName();
  body[QStringLiteral("platform")] = platformString();

  const QByteArray payload = QJsonDocument(body).toJson(QJsonDocument::Compact);
  qDebug() << "registerCurrentDevice payload:" << payload;

  QNetworkReply *reply = m_networkManager->post(
      makeRequest(QStringLiteral("/devices/register")), payload);

  handleReply(reply, [this](const QJsonDocument &doc) {
    const QJsonObject o = doc.object();
    const QString evicted = o.value(QStringLiteral("evicted")).toString();

    emit deviceRegistered(evicted);
    fetchDevices();
  });
}

// ── POST /devices/heartbeat ─────────────────────────────────────────────────
void DeviceController::heartbeat() {
  QJsonObject body;
  body[QStringLiteral("device_id")] = m_currentDeviceId;

  QNetworkReply *reply = m_networkManager->post(
      makeRequest(QStringLiteral("/devices/heartbeat")),
      QJsonDocument(body).toJson(QJsonDocument::Compact));

  handleReply(reply, [](const QJsonDocument &) {});
}

// ── DELETE /devices/by-device-id/{device_id} ────────────────────────────────
void DeviceController::removeDevice(const QString &deviceId) {
  qDebug() << "device_id" << deviceId;
  setLoading(true);

  const QString path = QStringLiteral("/devices/by-device-id/") +
                       QString::fromUtf8(QUrl::toPercentEncoding(deviceId));

  QNetworkReply *reply = m_networkManager->deleteResource(makeRequest(path));

  handleReply(reply, [this, deviceId](const QJsonDocument &) {
    emit deviceRemoved(deviceId);
    fetchDevices();
  });
}

void DeviceController::removeOtherDevices() {
  // setLoading(true);

  // QUrl url(m_baseUrl + QStringLiteral("/devices/others"));
  // QUrlQuery query;
  // query.addQueryItem(QStringLiteral("device_id"), m_currentDeviceId);
  // url.setQuery(query);

  // QNetworkRequest req(url);
  // req.setHeader(QNetworkRequest::ContentTypeHeader,
  //               QStringLiteral("application/json"));
  // if (!m_token.isEmpty())
  //   req.setRawHeader("Authorization", "Bearer " + m_token.toUtf8());

  // QNetworkReply *reply = m_nam->deleteResource(req);

  // handleReply(reply, [this](const QJsonDocument &) { fetchDevices(); });
}
