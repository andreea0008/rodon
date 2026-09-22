#include "ConnectionController.h"
#include "KeychainStore.h"
#include "WgKeys.h"
#include <QElapsedTimer>
#include <QSettings>
#include <QThread>
#include <QTimer>

ConnectionController::ConnectionController(NetworkManager *nm, QObject *parent)
    : QObject(parent) {
  networkManager = nm;
#if defined(Q_OS_IOS) || defined(Q_OS_MACOS)
  m_tunnel = new TunnelBridge(this);
  m_tunnel->refreshStatus();
  connect(m_tunnel, &TunnelBridge::connected, this, [this] {
    updateIpAndCountry();
    ping();
    setStatus(Connected);
  });
  connect(m_tunnel, &TunnelBridge::disconnected, this,
          [this] { setStatus(NotConnected); });
  connect(m_tunnel, &TunnelBridge::failed, this, [this](const QString &r) {
    m_lastError = r;
    emit lastErrorChanged();
    setStatus(Error);
  });
#endif

  internetCheckTimer = new QTimer(this);
  connect(internetCheckTimer, &QTimer::timeout, this,
          &ConnectionController::checkInternet);
  internetCheckTimer->start(5000);
  checkInternet();
}

ConnectionController::Status ConnectionController::status() const {
  return m_status;
}

QString ConnectionController::lastError() const { return m_lastError; }

QString ConnectionController::serverEndpoint() const {
  return m_serverEndpoint;
}

QString ConnectionController::assignedIp() const { return m_assignedIp; }

void ConnectionController::connectToLocation(const QString &locationId,
                                             const QString &deviceId) {
  if (m_status == Status::Connecting || m_status == Status::Connected)
    return;

  m_lastError = "";
  emit lastErrorChanged();
  setStatus(Status::Connecting);

  QJsonObject o;
  o["location_id"] = locationId;
  o["device_id"] = deviceId;

  // QSettings s;
  // QString privKey = s.value(QStringLiteral("wg/private_key"))
  //                       .toString(); // з QSettings/Keychain, див. нижче
  // QString pubKey;
  // if (privKey.isEmpty()) {
  //   WgKeyPair kp = WgKeys::generate();
  //   privKey = kp.privateKey;
  //   pubKey = kp.publicKey;
  //   s.setValue(QStringLiteral("wg/private_key"), privKey);
  // } else {
  //   pubKey = WgKeys::publicFromPrivate(privKey);
  // }

  QString privKey = KeychainStore::loadPrivateKey();
  QString pubKey;
  if (privKey.isEmpty()) {
    WgKeyPair kp = WgKeys::generate();
    privKey = kp.privateKey;
    pubKey = kp.publicKey;
    KeychainStore::savePrivateKey(privKey);
  } else {
    pubKey = WgKeys::publicFromPrivate(privKey);
  }

  o["public_key"] = pubKey;
  qDebug() << "Send object " << o;

  QNetworkReply *reply =
      networkManager->post(makeRequest(QStringLiteral("/connect")),
                           QJsonDocument(o).toJson(QJsonDocument::Compact));

  handleReply(reply, [this](const QJsonDocument &doc) {
    const QJsonObject o = doc.object();
    m_serverPublicKey = o.value(QStringLiteral("server_public_key")).toString();
    m_serverEndpoint = o.value(QStringLiteral("endpoint")).toString();
    m_assignedIp = o.value(QStringLiteral("allowed_ip")).toString();
    m_dns = o.value(QStringLiteral("dns")).toString();
    emit peerConfigChanged();

#if defined(Q_OS_IOS)
    m_tunnel->start(m_serverPublicKey, m_serverEndpoint, m_assignedIp, m_dns);
#elif defined(Q_OS_MACOS)
    // TODO: реальний macOS-тунель (System Extension) — окремий етап
    // qDebug() <<
    m_tunnel->start(m_serverPublicKey, m_serverEndpoint, m_assignedIp, m_dns);
    QTimer::singleShot(1500, this, [this] {
        updateIpAndCountry();
        ping();
        setStatus(Connected);
    });
#elif defined(Q_OS_ANDROID)
      // TODO: Android VPN-сервіс (інша архітектура)
      // поки мок:
      QTimer::singleShot(1500, this, [this] { setStatus(Connected); });
#elif defined(Q_OS_WIN)
      // TODO: Windows WireGuard-тунель
      QTimer::singleShot(1500, this, [this] { setStatus(Connected); });
#else
      // desktop dev/mock
      QTimer::singleShot(1500, this, [this] { setStatus(Connected); });
#endif
  });
}

void ConnectionController::disconnect(const QString &deviceId) {
  if (m_status == NotConnected || m_status == Disconnecting)
    return;

  setStatus(Disconnecting);

  QJsonObject body;
  body[QStringLiteral("device_id")] = deviceId;

  QNetworkReply *reply =
      networkManager->post(makeRequest(QStringLiteral("/disconnect")),
                           QJsonDocument(body).toJson(QJsonDocument::Compact));

  handleReply(reply, [this](const QJsonDocument &) {
    // ── Later: TunnelBackend->stop() ──
    stopTunnel();
    m_serverEndpoint.clear();
    m_assignedIp.clear();
    emit peerConfigChanged();
    setStatus(Disconnecting);
    QTimer::singleShot(3000, [this] { setStatus(NotConnected); });
  });
}

QNetworkRequest ConnectionController::makeRequest(const QString &endpoint) {
  QNetworkRequest req(QUrl(RODON_URL + endpoint));
  req.setHeader(QNetworkRequest::ContentTypeHeader,
                QStringLiteral("application/json"));
  req.setRawHeader("Authorization",
                   "Bearer " + networkManager->getToken().toUtf8());
  return req;
}

void ConnectionController::handleReply(
    QNetworkReply *reply,
    std::function<void(const QJsonDocument &)> onSuccess) {
  connect(reply, &QNetworkReply::finished, this, [this, reply, onSuccess]() {
    reply->deleteLater();
    const int code =
        reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const QByteArray raw = reply->readAll();
    qDebug() << "[handleReply] code:" << code << "err:" << reply->error()
             << "body:" << raw; // ← додай цей лог
    if (reply->error() != QNetworkReply::NoError) {
      QString msg = reply->errorString();
      if (!raw.isEmpty()) {
        const auto obj = QJsonDocument::fromJson(raw).object();
        if (obj.contains(QStringLiteral("error")))
          msg = obj.value(QStringLiteral("error")).toString();
      }
      if (code == 503)
        msg = tr("No servers available. Please try again later.");
      setError(msg);
      return;
    }
    const QJsonDocument doc = QJsonDocument::fromJson(raw);
    onSuccess(doc);
  });
}

void ConnectionController::setStatus(Status s) {
  m_status = s;
  emit statusChanged();
}

void ConnectionController::updateIpAndCountry() {
  QNetworkRequest req(QUrl("https://ipapi.co/json/"));
  req.setHeader(QNetworkRequest::UserAgentHeader, "ExchangeApp/1.0");
  auto *reply = networkManager->get(req);
  connect(reply, &QNetworkReply::finished, this, [this, reply]() {
    reply->deleteLater();
    if (reply->error() != QNetworkReply::NoError) {
      qDebug() << "error" << reply->errorString();
      return;
    }
    const auto doc = QJsonDocument::fromJson(reply->readAll());
    const auto obj = doc.object();
    m_currentIp = obj["ip"].toString();
    m_currentCountry = obj["country_name"].toString();
    m_currentCode = obj["country_code"].toString();
    m_currentCity = obj["city"].toString();
    emit currentCityChanged();
    emit currentIpChanged();
    emit currentCountryChanged();
    emit currentCodeChanged();
  });
}

void ConnectionController::ping() {
  QUrl url = QUrl("http://2.28.64.194:3000/health");
  QNetworkRequest req(QUrl(QStringLiteral("http://2.28.64.194:3000/health")));
  req.setAttribute(QNetworkRequest::CacheLoadControlAttribute,
                   QNetworkRequest::AlwaysNetwork);
  auto *timer = new QElapsedTimer;
  timer->start();
  QNetworkReply *reply = networkManager->get(req);
  connect(reply, &QNetworkReply::finished, this, [this, reply, timer]() {
    const int ms = static_cast<int>(timer->elapsed());
    delete timer;
    reply->deleteLater();
    setCurrentPing("~ ms");

    if (reply->error() == QNetworkReply::NoError) {
      setCurrentPing(QString("%1 ms").arg(ms));
    }
  });
}

void ConnectionController::checkInternet() {
  QNetworkRequest req(
      QUrl(QStringLiteral("https://cloudflare.com/cdn-cgi/trace")));
  req.setAttribute(QNetworkRequest::CacheLoadControlAttribute,
                   QNetworkRequest::AlwaysNetwork);
  req.setTransferTimeout(4000);
  QNetworkReply *reply = networkManager->get(req);
  connect(reply, &QNetworkReply::finished, this, [this, reply]() {
    reply->deleteLater();
    const bool ok =
        reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).isValid();
    setIsOnline(ok);
    if ((m_status == Status::Connected || m_status == Status::Connecting ||
         m_status == Status::Disconnecting ||
         m_status == Status::NotConnected) &&
        !m_isOnline) {
      setStatus(Status::Offline);
    } else if (m_isOnline && m_status == Status::Offline) {
      setStatus(Status::NotConnected);
    }
  });
}

void ConnectionController::stopTunnel() {
#if defined(Q_OS_IOS) || defined(Q_OS_MACOS)
  m_tunnel->stop();
#endif
}

void ConnectionController::refreshStatus() {
#if defined(Q_OS_IOS) || defined(Q_OS_MACOS)
  m_tunnel->refreshStatus();
#endif
}

void ConnectionController::setError(const QString &error) {
  m_lastError = error;
  emit lastErrorChanged();
  setStatus(Status::Error);
}

QString ConnectionController::currentIp() const { return m_currentIp; }

QString ConnectionController::currentCountry() const {
  return m_currentCountry;
}

QString ConnectionController::currentCode() const { return m_currentCode; }

QString ConnectionController::currentPing() const { return m_currentPing; }

void ConnectionController::setCurrentPing(const QString &newCurrentPing) {
  if (m_currentPing == newCurrentPing)
    return;
  m_currentPing = newCurrentPing;
  emit currentPingChanged();
}

QString ConnectionController::currentCity() const { return m_currentCity; }

bool ConnectionController::isOnline() const { return m_isOnline; }

void ConnectionController::setIsOnline(bool newIsOnline) {
  if (m_isOnline == newIsOnline)
    return;
  m_isOnline = newIsOnline;
  emit isOnlineChanged();
}
