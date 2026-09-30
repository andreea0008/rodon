#ifndef MACOS_UTILS_H
#define MACOS_UTILS_H

#include <QJsonObject>
#include <QObject>
#include <QString>
#include <functional>

class ApplePlatformUtils : public QObject {
  Q_OBJECT
public:
  explicit ApplePlatformUtils(QObject *parent = nullptr);
  // static void init_sparkle();

#if defined(Q_OS_IOS) || defined(Q_OS_MACOS)
  // void triggerBiometric(const QString &reason = QString());
  // bool isBiometricAvailable();
#endif

#ifdef Q_OS_IOS
  void vibrate();
  QString model();
  void registerForRemoteNotifications();
  void handleNotification(const QString &payload);
#endif

signals:
  void biometricAuthResult(bool result);

#ifdef Q_OS_IOS
  void deviceTokenReceived(const QString &token);
  void registrationFailed(const QString &error);
  void notificationReceived(const QJsonObject &data);
#endif

private:
  // #if defined(Q_OS_IOS) || defined(Q_OS_MACOS)
  //   void
  //   authenticateWithBiometric(const QString &reason,
  //                             std::function<void(bool, const char *)>
  //                             callback);
  //   void
  //   requestPasscodeFallback(std::function<void(bool, const char *)>
  //   callback);
  // #endif
};

#endif // MACOS_UTILS_H
