#include "AuthController.h"

NetworkManager *AuthController::getNetworkManager() const {
  return networkManager;
}

AuthController::AuthController(QObject *parent) : QObject(parent) {
  networkManager = new NetworkManager(this);
}

void AuthController::registration(const QString &reserveEmail) {
  qDebug() << "Begin create with email:" << reserveEmail << createUrl;

  QJsonObject body;
  body["recovery_email"] =
      reserveEmail.isEmpty() ? QJsonValue::Null : QJsonValue(reserveEmail);

  QNetworkRequest request(createUrl);
  request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
  request.setRawHeader("Accept", "application/json");

  QByteArray data = QJsonDocument(body).toJson(QJsonDocument::Compact);
  auto reply = networkManager->post(request, data);

  connect(reply, &QNetworkReply::finished, this, [reply, this]() {
    const int status =
        reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const QByteArray response = reply->readAll();

    qDebug() << "Status:" << status;
    qDebug() << "Response:" << response;

    if (reply->error() != QNetworkReply::NoError) {
      qDebug() << "Error:" << reply->errorString();
    } else {
      QJsonDocument doc = QJsonDocument::fromJson(response);
      qDebug() << doc;
      auto receiveCode = doc.object()["account_code"].toString();
      emit accountCode(receiveCode);
    }

    reply->deleteLater();
  });
}

void AuthController::auth(const QString &code) {
  QJsonObject body;
  body["account_code"] = code;

  QNetworkRequest request(sighInUrl);
  request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
  request.setRawHeader("Accept", "application/json");

  QByteArray data = QJsonDocument(body).toJson(QJsonDocument::Compact);
  auto reply = networkManager->post(request, data);

  connect(reply, &QNetworkReply::finished, this, [reply, this]() {
    const int status =
        reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const QByteArray response = reply->readAll();

    qDebug() << "Status:" << status;
    qDebug() << "Response:" << response;

    if (reply->error() != QNetworkReply::NoError) {
      qDebug() << "Error:" << reply->errorString();
      emit errorAuthorization();
    } else {
      QJsonDocument doc = QJsonDocument::fromJson(response);
      QJsonObject o = doc.object();
      token = o["token"].toString();
      networkManager->setToken(token);
      emit authorized();
    }

    reply->deleteLater();
  });
}

void AuthController::registerDevice(const QString &body) {
  QNetworkRequest request(registerDeviceUrl);
  request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
  request.setRawHeader("Accept", "application/json");
  request.setRawHeader("Authorization", "Bearer " + token.toUtf8());
  auto reply = networkManager->post(
      request,
      QJsonDocument::fromJson(body.toLatin1()).toJson(QJsonDocument::Compact));

  connect(reply, &QNetworkReply::finished, this, [reply, this]() {
    const int status =
        reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const QByteArray response = reply->readAll();

    qDebug() << "Status:" << status;
    qDebug() << "Response:" << response;

    if (reply->error() != QNetworkReply::NoError) {
      qDebug() << "Error:" << reply->errorString();
    } else {
      qDebug() << "device added";
      emit updateDeviceList();
    }

    reply->deleteLater();
  });
}

void AuthController::aboutMe() {
  QNetworkRequest request(aboutMeUrl);
  request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
  request.setRawHeader("Accept", "application/json");
  request.setRawHeader("Authorization", "Bearer " + token.toUtf8());
  auto reply = networkManager->get(request);

  connect(reply, &QNetworkReply::finished, this, [reply, this]() {
    QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
    QJsonObject o = doc.object();
    AccountMe me;
    me.createdAt =
        QDateTime::fromString(o["created_at"].toString(), Qt::ISODateWithMs);
    me.emailVerified = o["email_verified"].toBool();
    me.id = o["id"].toString();
    me.plan = o["plan"].toString();
    emit myAccount(me);
    reply->deleteLater();
  });
}
