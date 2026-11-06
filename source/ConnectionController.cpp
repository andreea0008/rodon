#include "ConnectionController.h"
#include "KeychainStore.h"
#include "WgKeys.h"
#include <QElapsedTimer>
#include <QSettings>
#include <QThread>
#include <QTimer>
#include <qguiapplication.h>
#include <sodium.h>

#ifdef Q_OS_MACOS
#include "ios/SystemExtensionManager.h"
#endif

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
  connect(qApp, &QGuiApplication::applicationStateChanged, this,
          [this](Qt::ApplicationState s) {
            if (s == Qt::ApplicationActive)
              refreshStatus();
          });
  connect(m_tunnel, &TunnelBridge::disconnected, this,
          [this] { setStatus(NotConnected); });
  connect(m_tunnel, &TunnelBridge::failed, this, [this](const QString &r) {
    m_lastError = r;
    emit lastErrorChanged();
    setStatus(Error);
  });
#endif

#ifdef Q_OS_WIN
  m_winTunnel = new WinTunnel(this);
  connect(m_winTunnel, &WinTunnel::stateChanged, this,
          [this](WinTunnel::State s) {
            qDebug() << "new state:" << s;
            switch (s) {
            case WinTunnel::State::Connecting:
              setStatus(Connecting);
              break;
            case WinTunnel::State::Connected:
              setStatus(Connected);
              break;
            case WinTunnel::State::Disconnecting:
              setStatus(Disconnecting);
              break;
            case WinTunnel::State::Disconnected:
              setStatus(NotConnected);
              break;
            }
          });
  connect(m_winTunnel, &WinTunnel::errorOccurred, this,
          [this](const QString &msg) {
            qWarning() << "WinTunnel:" << msg;
            m_lastError = msg;
            emit lastErrorChanged();
          });
  m_winTunnel->refresh();
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
  m_currentLocation = locationId;
  m_currentDeviceId = deviceId;

#ifdef Q_OS_MACOS
  auto *sx = SystemExtensionManager::instance();
  if (!sx->isReady()) {
    if (!m_waitingForSysExt) {
      m_waitingForSysExt = true;
      setIsShowSystemExtention(true);
      connect(
          sx, &SystemExtensionManager::ready, this,
          [this, locationId, deviceId]() {
            m_waitingForSysExt = false;
            setIsShowSystemExtention(false);
            connectToLocation(locationId, deviceId);
          },
          Qt::SingleShotConnection);
    }
    sx->activate();
    return;
  }
#endif

  m_lastError.clear();
  emit lastErrorChanged();
  setStatus(Status::Connecting);

  // Ключ: беремо збережений або генеруємо новий
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

  QJsonObject o;
  o["location_id"] = locationId;
  o["device_id"] = deviceId;
  o["public_key"] = pubKey;

  QNetworkReply *reply =
      networkManager->post(makeRequest(QStringLiteral("/connect")),
                           QJsonDocument(o).toJson(QJsonDocument::Compact));

  // reply НЕ захоплюємо: handleReply сам робить deleteLater
  handleReply(reply, [this, privKey](const QJsonDocument &doc) {
    m_keyRetried = false;
    const QJsonObject o = doc.object();
    m_serverPublicKey = o.value(QStringLiteral("server_public_key")).toString();
    m_serverEndpoint = o.value(QStringLiteral("endpoint")).toString();
    m_assignedIp = o.value(QStringLiteral("allowed_ip")).toString();
    m_dns = o.value(QStringLiteral("dns")).toString();
    emit peerConfigChanged();

#if defined(Q_OS_IOS) || defined(Q_OS_MACOS)
    // статус Connected прийде з TunnelBridge::connected
    m_tunnel->start(m_serverPublicKey, m_serverEndpoint, m_assignedIp, m_dns,
                    privKey);
#elif defined(Q_OS_WIN)
        m_winTunnel->start(m_serverPublicKey, m_serverEndpoint, m_assignedIp, m_dns,
                           privKey);
#elif defined(Q_OS_ANDROID)
        // TODO: Android VPN-сервіс; поки мок
        QTimer::singleShot(1500, this, [this] { setStatus(Connected); });
#else
        QTimer::singleShot(1500, this, [this] { setStatus(Connected); });
#endif
  });
}

void ConnectionController::disconnect(const QString &deviceId) {
  if (m_status == NotConnected || m_status == Disconnecting)
    return;

  setStatus(Disconnecting);
  // Тунель зупиняємо одразу — незалежно від відповіді сервера
  stopTunnel();
  m_serverEndpoint.clear();
  m_assignedIp.clear();
  emit peerConfigChanged();

  QJsonObject body;
  body[QStringLiteral("device_id")] = deviceId;
  QNetworkReply *reply =
      networkManager->post(makeRequest(QStringLiteral("/disconnect")),
                           QJsonDocument(body).toJson(QJsonDocument::Compact));
  handleReply(reply, [](const QJsonDocument &) {});

#if !defined(Q_OS_IOS) && !defined(Q_OS_MACOS) && !defined(Q_OS_WIN)
  // на Apple/Windows NotConnected прийде від тунелю
  QTimer::singleShot(1000, this, [this] { setStatus(NotConnected); });
#endif
}

void ConnectionController::handleReply(
    QNetworkReply *reply,
    std::function<void(const QJsonDocument &)> onSuccess) {
  connect(reply, &QNetworkReply::finished, this, [this, reply, onSuccess]() {
    reply->deleteLater();
    const int code =
        reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const QByteArray raw = reply->readAll();
    qDebug() << "[handleReply]" << reply->url().path() << "code:" << code;

    if (reply->error() != QNetworkReply::NoError) {
      // 409 від /connect: ключ належить іншому пристрою — новий ключ, ОДИН
      // повтор
      if (code == 409 && raw.contains("key_in_use") && !m_keyRetried) {
        qWarning() << "connect: key belongs to another device, regenerating";
        m_keyRetried = true;
        KeychainStore::clearPrivateKey();
        setStatus(NotConnected); // інакше connectToLocation одразу вийде
        connectToLocation(m_currentLocation, m_currentDeviceId);
        return;
      }
      m_keyRetried = false;

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
    onSuccess(QJsonDocument::fromJson(raw));
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

QString ConnectionController::ensurePublicKey() {
  QByteArray sk =
      QByteArray::fromBase64(KeychainStore::loadPrivateKey().toLatin1());
  if (sk.size() != crypto_scalarmult_SCALARBYTES) {
    sk.resize(crypto_scalarmult_SCALARBYTES);
    randombytes_buf(sk.data(), sk.size());
    sk[0] &= 248; // clamping Curve25519, як у wg genkey
    sk[31] = (sk[31] & 127) | 64;
    KeychainStore::savePrivateKey(QString::fromLatin1(sk.toBase64()));
  }
  QByteArray pk(crypto_scalarmult_BYTES, 0);
  crypto_scalarmult_base(
      reinterpret_cast<unsigned char *>(pk.data()),
      reinterpret_cast<const unsigned char *>(sk.constData()));
  sodium_memzero(sk.data(), sk.size());
  return QString::fromLatin1(pk.toBase64());
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
#elif defined(Q_OS_WIN)
  m_winTunnel->stop();
#endif
}

void ConnectionController::refreshStatus() {
#if defined(Q_OS_IOS) || defined(Q_OS_MACOS)
  m_tunnel->refreshStatus();
#endif
}

void ConnectionController::removeDevice(const QString &id) {
  QNetworkReply *reply =
      networkManager->deleteResource(makeRequest("/devices/" + id));
  connect(reply, &QNetworkReply::finished, this, [this, reply, id] {
    reply->deleteLater();
    if (reply->error() != QNetworkReply::NoError) {
      m_lastError = reply->errorString();
      emit lastErrorChanged();
      return;
    }
    if (id == m_currentDeviceId) { // видалили себе
      // emit currentDeviceRemoved(); // → ConnectionController::disconnect()
      // disconnect(id);
      emit logout();
    }
    emit updateDeviceList(); // оновити список
  });
}

void ConnectionController::clearPrivateKey() {
  KeychainStore::clearPrivateKey();
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

bool ConnectionController::isShowSystemExtention() const {
#ifdef Q_OS_MACOS
  return m_isShowSystemExtention;
#else
  return false;
#endif
}

void ConnectionController::setIsShowSystemExtention(
    bool newIsShowSystemExtention) {
#ifdef Q_OS_MACOS
  if (m_isShowSystemExtention == newIsShowSystemExtention)
    return;
  m_isShowSystemExtention = newIsShowSystemExtention;
  emit isShowSystemExtentionChanged();
#else
  Q_UNUSED(newIsShowSystemExtention);
#endif
}
