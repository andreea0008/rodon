#pragma once

#include <QObject>
#include <QString>

class SystemExtensionManager : public QObject {
  Q_OBJECT
  Q_PROPERTY(State state READ state NOTIFY stateChanged)
  Q_PROPERTY(QString errorString READ errorString NOTIFY stateChanged)
  Q_PROPERTY(bool ready READ isReady NOTIFY stateChanged)

public:
  enum State {
    Unknown,
    Activating,
    NeedsApproval,
    Ready,
    RebootRequired,
    NotInApplications,
    Failed
  };
  Q_ENUM(State)

  static SystemExtensionManager *instance();

  State state() const { return m_state; }
  QString errorString() const { return m_error; }
  bool isReady() const { return m_state == Ready; }

  Q_INVOKABLE void activate();
  Q_INVOKABLE void deactivate();
  Q_INVOKABLE void openSettings();
  Q_INVOKABLE void moveToApplications();
  Q_INVOKABLE bool isInApplications() const;

  void onNeedsApproval();
  void onActivated(bool needsReboot);
  void onDeactivated();
  void onFailed(const QString &message, long code);

signals:
  void stateChanged();
  void ready();

private:
  explicit SystemExtensionManager(QObject *parent = nullptr);
  void setState(State s, const QString &error = QString());

  State m_state = Unknown;
  QString m_error;
  bool m_requestInFlight = false;
};