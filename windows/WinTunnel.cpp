#include "WinTunnel.h"
#include <QLocalSocket>
#include <memory>
#include <qdebug.h>

namespace {
const QString kPipe = QStringLiteral("RodONService");   // \\.\pipe\RodONService
constexpr int kPollMs             = 1000;
constexpr qint64 kConnectTimeout   = 20000;  // перший handshake
constexpr qint64 kReconnectTimeout = 120000; // handshake зник після підключення
constexpr int kRequestTimeoutMs   = 40000;
}

WinTunnel::WinTunnel(QObject* parent) : QObject(parent)
{
    m_pollTimer.setInterval(kPollMs);
    connect(&m_pollTimer, &QTimer::timeout, this, &WinTunnel::poll);
}

void WinTunnel::start(const QString& serverPublicKey, const QString& endpoint,
                      const QString& assignedIp, const QString& dns,
                      const QString& privateKey)
{
    ++m_generation;
    m_pollTimer.stop();
    m_wasConnected = false;
    m_connectTimer.start();
    setState(State::Connecting);
    qDebug() << "WinTunnel::start pub=" << serverPublicKey << "endpoint=" << endpoint
             << "ip=" << assignedIp << "dns=" << dns << "privLen=" << privateKey.size();

    QByteArray req = "CONNECT\n";
    req += "private_key=" + privateKey.toUtf8() + "\n";
    req += "public_key=" + serverPublicKey.toUtf8() + "\n";
    req += "address=" + assignedIp.toUtf8() + "\n";
    req += "dns=" + dns.toUtf8() + "\n";
    req += "endpoint=" + endpoint.toUtf8() + "\n\n";

    const quint64 gen = m_generation;
    send(req, [this, gen](bool ok, const QByteArray& line) {
        if (gen != m_generation) return;
        if (!ok) {
            fail(tr("RodON service is not running. Please reinstall the app."));
            return;
        }
        if (!line.startsWith("OK")) {
            fail(QString::fromUtf8(line.mid(4)));
            return;
        }
        m_connectTimer.start();
        m_pollTimer.start();
    });
    req.fill('\0');
}

void WinTunnel::stop()
{
    ++m_generation;
    m_pollTimer.stop();
    if (m_state == State::Disconnected) return;
    setState(State::Disconnecting);

    const quint64 gen = m_generation;
    send("DISCONNECT\n\n", [this, gen](bool ok, const QByteArray& line) {
        if (gen != m_generation) return;
        if (!ok || !line.startsWith("OK"))
            emit errorOccurred(tr("Could not disconnect: %1")
                                   .arg(ok ? QString::fromUtf8(line) : tr("service unavailable")));
        setState(State::Disconnected);
    });
}

void WinTunnel::refresh()
{
    poll();
}

void WinTunnel::poll()
{
    if (m_pollInFlight) return;
    m_pollInFlight = true;
    const quint64 gen = m_generation;
    send("STATUS\n\n", [this, gen](bool ok, const QByteArray& line) {
        m_pollInFlight = false;
        if (gen != m_generation || m_state == State::Disconnecting) return;
        if (!ok) {
            // служба недоступна: якщо ми не підключені — просто мовчимо
            if (m_state != State::Disconnected)
                fail(tr("Lost connection to RodON service"));
            return;
        }
        handleStatus(line.split(' '));
    });
}

void WinTunnel::handleStatus(const QList<QByteArray>& parts)
{
    if (parts.value(0) != "STATUS") return;
    const QByteArray st = parts.value(1);

    if (st == "connected") {
        const quint64 rx = parts.value(2).toULongLong();
        const quint64 tx = parts.value(3).toULongLong();
        if (rx != m_rx || tx != m_tx) {
            m_rx = rx; m_tx = tx;
            emit statsChanged(m_rx, m_tx);
        }
        m_wasConnected = true;
        if (!m_pollTimer.isActive()) m_pollTimer.start();
        setState(State::Connected);
    } else if (st == "connecting") {
        if (m_state != State::Connecting) {      // перший запуск або handshake застарів
            m_connectTimer.start();
            setState(State::Connecting);
        }
        if (!m_pollTimer.isActive()) m_pollTimer.start();
        const qint64 limit = m_wasConnected ? kReconnectTimeout : kConnectTimeout;
        if (m_connectTimer.elapsed() > limit)
            // з AllowedIPs 0.0.0.0/0 працює kill switch: без handshake інтернету немає,
            // тому тунель обов'язково знімаємо
            fail(tr("Server is not responding"));
    } else if (st == "error") {
        fail(tr("Tunnel failed to start (code %1)").arg(QString::fromUtf8(parts.value(4))));
    } else if (st == "disconnected") {
        m_pollTimer.stop();
        setState(State::Disconnected);
    }
    // "disconnecting" — просто чекаємо
}

void WinTunnel::fail(const QString& message)
{
    emit errorOccurred(message);
    ++m_generation;
    m_pollTimer.stop();
    send("DISCONNECT\n\n", [](bool, const QByteArray&) {});
    setState(State::Disconnected);
}

void WinTunnel::setState(State s)
{
    if (m_state == s) return;
    m_state = s;
    if (s == State::Disconnected) { m_rx = m_tx = 0; m_wasConnected = false; }
    emit stateChanged(s);
}

void WinTunnel::send(const QByteArray& request, Reply onReply)
{
    auto* sock = new QLocalSocket(this);
    auto buffer = std::make_shared<QByteArray>();
    auto done = std::make_shared<bool>(false);

    auto finish = [sock, buffer, done, onReply](bool ok) {
        if (*done) return;
        *done = true;
        const QByteArray line = buffer->trimmed();
        sock->abort();
        sock->deleteLater();
        onReply(ok, line);
    };

    connect(sock, &QLocalSocket::connected, sock, [sock, request] {
        sock->write(request);
    });
    connect(sock, &QLocalSocket::readyRead, sock, [sock, buffer, finish] {
        buffer->append(sock->readAll());
        if (buffer->contains('\n')) finish(true);
    });
    connect(sock, &QLocalSocket::errorOccurred, sock, [buffer, finish](QLocalSocket::LocalSocketError) {
        finish(buffer->contains('\n'));
    });
    QTimer::singleShot(kRequestTimeoutMs, sock, [finish] { finish(false); });

    sock->connectToServer(kPipe);
}
