#include "RodonController.h"

RodonController::RodonController(AuthController *auth, QObject *parent)
    : QObject(parent), authController(auth) {
  _deviceController = new DeviceController(auth->getNetworkManager(), this);
  _locationController = new LocationController(auth->getNetworkManager(), this);
  _connectionController =
      new ConnectionController(auth->getNetworkManager(), this);

  connect(auth, &AuthController::authorized, this,
          [this, auth]() { auth->aboutMe(); });

  connect(auth, &AuthController::updateDeviceList, this, [this]() {
    qDebug() << "Update device list" << _deviceController;
    _deviceController->fetchDevices();
    _locationController->fetchLocations();
  });

  connect(auth, &AuthController::myAccount, this, [this](AccountMe me) {
    meAccount = me;
    meAccount.print();
    setIsFreeVersion(me.plan == "free");
    calculatePercentFreeLeave();
  });
}

DeviceController *RodonController::deviceController() const {
  return _deviceController;
}

void RodonController::calculatePercentFreeLeave() {
  QDateTime currentDT = QDateTime::currentDateTime();
  auto finishedAt = meAccount.createdAt.addDays(7).toSecsSinceEpoch();
  auto startedAt = meAccount.createdAt.toSecsSinceEpoch();
  auto leaveSec = finishedAt - currentDT.toSecsSinceEpoch();

  auto onehundred = finishedAt - startedAt;
  auto s = (1.0 - ((double)leaveSec / (double)onehundred)) * 100;
  if (s > 100) {
    s = 100;
  }
  if (s < 100 && reverseTimer == nullptr) {
    qDebug() << "Timer started.";
    reverseTimer = new QTimer(this);
    reverseTimer->setInterval(REVERSE_INTERVAL_TIMER);
    connect(reverseTimer, &QTimer::timeout, this,
            &RodonController::calculatePercentFreeLeave);
    reverseTimer->start();
  }

  qDebug() << "StartedAt:" << startedAt;
  qDebug() << "FinishedAt:" << finishedAt;
  qDebug() << "LeaveSec:" << leaveSec << onehundred << static_cast<int>(s);

  setProgress(static_cast<int>(s));
}

int RodonController::progress() const { return m_progress; }

void RodonController::setProgress(int newProgress) {
  if (m_progress == newProgress)
    return;
  m_progress = newProgress;
  emit progressChanged();
}

LocationController *RodonController::locationController() const {
  return _locationController;
}

ConnectionController *RodonController::connectionController() const {
  return _connectionController;
}

bool RodonController::isFreeVersion() const { return m_isFreeVersion; }

void RodonController::setIsFreeVersion(bool newIsFreeVersion) {
  if (m_isFreeVersion == newIsFreeVersion)
    return;
  m_isFreeVersion = newIsFreeVersion;
  emit isFreeVersionChanged();
}
