#pragma once
#include <QObject>
#include <QString>

class TunnelBridge : public QObject {
  Q_OBJECT
public:
  explicit TunnelBridge(QObject *parent = nullptr);
  ~TunnelBridge();

  void start(const QString &serverPublicKey, const QString &endpoint,
             const QString &assignedIp, const QString &dns);
  void stop();
  void refreshStatus();

signals:
  void connected();
  void disconnected();
  void failed(const QString &reason);

private:
  void *m_observer = nullptr;
};
