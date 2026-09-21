#pragma once
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>

class NetworkManager : public QObject {
  Q_OBJECT
  QNetworkAccessManager *m_nm;
  QString token;

public:
  explicit NetworkManager(QObject *parent = nullptr) {
    m_nm = new QNetworkAccessManager(this);
  }

  QNetworkReply *post(const QNetworkRequest &request, const QByteArray &data) {
    return m_nm->post(request, data);
  }

  QNetworkReply *get(const QNetworkRequest &request) {
    return m_nm->get(request);
  }

  QNetworkReply *deleteResource(const QNetworkRequest &request) {
    return m_nm->deleteResource(request);
  }
  QString getToken() const { return token; }
  void setToken(const QString &newToken) { token = newToken; }
};
