#pragma once
// WinTunnel — клієнт RodONService (Windows). Аналог TunnelBridge на Apple.
// Сам тунель піднімає служба; цей клас лише шле їй команди через named pipe
// і раз на секунду питає статус.
#include <QObject>
#include <QTimer>
#include <QElapsedTimer>
#include <functional>

class WinTunnel : public QObject
{
    Q_OBJECT
public:
    enum class State { Disconnected, Connecting, Connected, Disconnecting };
    Q_ENUM(State)

    explicit WinTunnel(QObject* parent = nullptr);

    void start(const QString& serverPublicKey, const QString& endpoint,
               const QString& assignedIp, const QString& dns,
               const QString& privateKey);
    void stop();
    // Викликати при старті апки: тунель міг лишитись піднятим після закриття GUI
    void refresh();

    State state() const { return m_state; }
    quint64 rxBytes() const { return m_rx; }
    quint64 txBytes() const { return m_tx; }

signals:
    void stateChanged(WinTunnel::State state);
    void errorOccurred(const QString& message);
    void statsChanged(quint64 rxBytes, quint64 txBytes);

private:
    using Reply = std::function<void(bool ok, const QByteArray& line)>;
    void send(const QByteArray& request, Reply onReply);
    void poll();
    void handleStatus(const QList<QByteArray>& parts);
    void fail(const QString& message);
    void setState(State s);

    QTimer m_pollTimer;
    QElapsedTimer m_connectTimer;
    State m_state = State::Disconnected;
    bool m_wasConnected = false;
    bool m_pollInFlight = false;
    quint64 m_generation = 0;
    quint64 m_rx = 0, m_tx = 0;
};
