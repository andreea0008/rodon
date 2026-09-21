#pragma once

#include "AuthController.h"
#include "ConnectionController.h"
#include "DeviceController.h"
#include "LocationController.h"
#include <QObject>
#include <QTimer>

const int REVERSE_INTERVAL_TIMER = 500000;

class RodonController : public QObject {
  Q_OBJECT

  AuthController *authController = nullptr;
  DeviceController *_deviceController = nullptr;
  LocationController *_locationController = nullptr;
  ConnectionController *_connectionController = nullptr;

  AccountMe meAccount;
  QTimer *reverseTimer = nullptr;
  int m_progress = 0;
  bool m_isFreeVersion = true;

public:
  Q_PROPERTY(DeviceController *deviceController READ deviceController CONSTANT)
  Q_PROPERTY(
      LocationController *locationController READ locationController CONSTANT)
  Q_PROPERTY(ConnectionController *connectionController READ
                 connectionController CONSTANT)
  Q_PROPERTY(
      int progress READ progress WRITE setProgress NOTIFY progressChanged)
  Q_PROPERTY(bool isFreeVersion READ isFreeVersion WRITE setIsFreeVersion NOTIFY
                 isFreeVersionChanged)

  explicit RodonController(AuthController *auth, QObject *parent = nullptr);

  DeviceController *deviceController() const;
  LocationController *locationController() const;
  ConnectionController *connectionController() const;

  void calculatePercentFreeLeave();
  int progress() const;
  void setProgress(int newProgress);

  bool isFreeVersion() const;
  void setIsFreeVersion(bool newIsFreeVersion);

signals:
  void progressChanged();
  void isFreeVersionChanged();
};
