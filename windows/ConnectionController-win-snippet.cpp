// ===================== ConnectionController: Windows =====================
// Заміна mock-гілки Q_OS_WIN (setStatus(Connected) через QTimer).
// Назви статусів/методів підлаштуй під свої — логіка та сама, що з TunnelBridge.

// ---- ConnectionController.h
#ifdef Q_OS_WIN
class WinTunnel;
#endif
// ...у private:
#ifdef Q_OS_WIN
    WinTunnel* m_winTunnel = nullptr;
#endif

// ---- ConnectionController.cpp
#ifdef Q_OS_WIN
#include "WinTunnel.h"
#endif

// у конструкторі:
#ifdef Q_OS_WIN
    m_winTunnel = new WinTunnel(this);
    connect(m_winTunnel, &WinTunnel::stateChanged, this, [this](WinTunnel::State s) {
        switch (s) {
        case WinTunnel::State::Connecting:    setStatus(Connecting);    break;
        case WinTunnel::State::Connected:     setStatus(Connected);     break;
        case WinTunnel::State::Disconnecting: setStatus(Disconnecting); break;
        case WinTunnel::State::Disconnected:  setStatus(Disconnected);  break;
        }
    });
    connect(m_winTunnel, &WinTunnel::errorOccurred, this, [this](const QString& msg) {
        qWarning() << "WinTunnel:" << msg;
        emit errorOccurred(msg);          // або як у тебе показується помилка в QML
    });
    m_winTunnel->refresh();              // тунель міг лишитись піднятим після закриття апки
#endif

// у connectToLocation(), після відповіді бекенду /connect
// (там, де на Apple викликається TunnelBridge::start):
#ifdef Q_OS_WIN
    m_winTunnel->start(serverPublicKey, endpoint, assignedIp, dns,
                       KeychainStore::loadPrivateKey());
#endif

// у disconnect():
#ifdef Q_OS_WIN
    m_winTunnel->stop();
#endif
