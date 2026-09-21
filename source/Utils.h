#pragma once

#include <QClipboard>
#include <QCoreApplication>
#include <QGuiApplication>
#include <QObject>
#include <QQmlEngine>
#include <QSettings>
#include <QSysInfo>
#include <QUuid>
#include <qqmlintegration.h>

#ifdef Q_OS_IOS
#include "ios/MacosUtils.h"
#endif

class PageTypes : public QObject {
  Q_OBJECT
  QML_ELEMENT
  QML_UNCREATABLE("")

public:
  enum Page { Home = 1, Locations, Settings };
  Q_ENUM(Page);
};

class ConnectionStatus : public QObject {
  Q_OBJECT
  QML_ELEMENT
  QML_UNCREATABLE("");

public:
  enum Status {
    NotConnected = 1,
    Connecting,
    Connected,
    Disconnecting,
    Error,
    Offline
  };
  Q_ENUM(Status);
};

class VUtils : public QObject {
  Q_OBJECT
  QML_ELEMENT

#ifdef Q_OS_ANDROID
  QJniObject vibratorService;
#endif
#ifdef Q_OS_IOS
  ApplePlatformUtils *iosUtils;
#endif

public:
  VUtils(QObject *parent = nullptr) : QObject(parent) {
#ifdef Q_OS_ANDROID
    QJniObject vibroString = QJniObject::fromString("vibrator");
    QJniObject activity = QNativeInterface::QAndroidApplication::context();
    QJniObject appctx = activity.callObjectMethod(
        "getApplicationContext", "()Landroid/content/Context;");
    vibratorService = appctx.callObjectMethod(
        "getSystemService", "(Ljava/lang/String;)Ljava/lang/Object;",
        vibroString.object<jstring>());
#endif

#ifdef Q_OS_IOS
    iosUtils = new ApplePlatformUtils(this);
#endif
  }

public slots:
  Q_INVOKABLE bool vibrate(int milliseconds = 400) {
#if defined(Q_OS_ANDROID)
    if (vibratorService.isValid()) {
      jlong ms = milliseconds;
      jboolean hasVibro =
          vibratorService.callMethod<jboolean>("hasVibrator", "()Z");
      vibratorService.callMethod<void>("vibrate", "(J)V", ms);
      return hasVibro;
    } else {
      eLog("[Android] No vibrator service available");
    }
#elif defined(Q_OS_IOS)
    iosUtils->vibrate();
#else
    Q_UNUSED(milliseconds)
#endif
    return false;
  };

  Q_INVOKABLE QString model() {
#if defined(Q_OS_ANDROID)
    // should add for android
#elif defined(Q_OS_IOS)
    return iosUtils->model();
#endif
    return "";
  }

  Q_INVOKABLE void copyText(const QString &text) {
    QGuiApplication::clipboard()->setText(text);
    vibrate();
  }
};

class DeviceInfo : public QObject {
  Q_OBJECT
  QML_ELEMENT
  QML_SINGLETON

  Q_PROPERTY(QString model READ model CONSTANT)
  Q_PROPERTY(QString os READ os CONSTANT)
  Q_PROPERTY(QString osVersion READ osVersion CONSTANT)
  Q_PROPERTY(QString appVersion READ appVersion CONSTANT)
  Q_PROPERTY(bool isIos READ isIos CONSTANT)
  Q_PROPERTY(bool isAndroid READ isAndroid CONSTANT)
  Q_PROPERTY(QString deviceId READ deviceId CONSTANT)

public:
  explicit DeviceInfo(QObject *parent = nullptr) : QObject(parent) {}

  static DeviceInfo *create(QQmlEngine *, QJSEngine *) {
    return new DeviceInfo();
  }

  QString model() const { return QSysInfo::machineHostName(); }
  QString os() const { return QSysInfo::productType(); }
  QString osVersion() const { return QSysInfo::productVersion(); }
  QString appVersion() const { return QCoreApplication::applicationVersion(); }

  bool isIos() const {
#ifdef Q_OS_IOS
    return true;
#else
    return false;
#endif
  }

  bool isAndroid() const {
#ifdef Q_OS_ANDROID
    return true;
#else
    return false;
#endif
  }

  QString deviceId() const {
    QSettings s("RodON", "device");
    if (!s.contains("uuid"))
      s.setValue("uuid", QUuid::createUuid().toString(QUuid::WithoutBraces));
    return s.value("uuid").toString();
  }
};
