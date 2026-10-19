#pragma once
// WinUpdater - auto-updates for Windows via WinSparkle (Sparkle port).
// Uses the same EdDSA key and server as Sparkle on macOS,
// but its own feed: appcast-windows.xml
#include <QObject>

class WinUpdater : public QObject
{
    Q_OBJECT
public:
    explicit WinUpdater(QObject* parent = nullptr);
    ~WinUpdater() override;

    // "Check for updates" button: shows the WinSparkle window
    Q_INVOKABLE void checkForUpdates();
};
