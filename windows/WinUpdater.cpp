#include "WinUpdater.h"
#include <QCoreApplication>
#include <QMetaObject>
#include <winsparkle.h>

namespace {
// Same values as SUFeedURL / SUPublicEDKey on macOS (Info.plist)
constexpr char kAppcastUrl[] = "https://2-28-64-194.sslip.io/updates/appcast-windows.xml";
constexpr char kEdKey[]      = RODON_SPARKLE_ED_KEY;   // passed from CMake
}

WinUpdater::WinUpdater(QObject* parent) : QObject(parent)
{
    // Name/version are read from the VERSIONINFO resource (rodon.rc)
    win_sparkle_set_appcast_url(kAppcastUrl);
    win_sparkle_set_eddsa_public_key(kEdKey);
    win_sparkle_set_automatic_check_for_updates(1);
    win_sparkle_set_update_check_interval(24 * 60 * 60);

    // The installer replaces RodON.exe, so the app must quit before it runs
    win_sparkle_set_can_shutdown_callback([]() -> int { return 1; });
    win_sparkle_set_shutdown_request_callback([] {
        QMetaObject::invokeMethod(qApp, &QCoreApplication::quit, Qt::QueuedConnection);
    });

    win_sparkle_init();   // also does the background check (no more than once a day)
}

WinUpdater::~WinUpdater()
{
    win_sparkle_cleanup();
}

void WinUpdater::checkForUpdates()
{
    win_sparkle_check_update_without_ui();
}
