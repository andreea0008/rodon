#include "ConnectionController.h"
#include "RodonController.h"
#include "Utils.h"
#include "source/TranslationManager.h"
#include <AuthController.h>
#include <QDir>
#include <QGuiApplication>
#include <QLockFile>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QTimer>

#ifdef Q_OS_MACOS
#include "SystemExtensionBridge.h"
#include "ios/SystemExtensionManager.h"
#endif

#if defined(Q_OS_MACOS) && defined(RODON_HAS_SPARKLE) && defined(IS_PRODUCTION)
#include "ios/SparkleUpdater.h"
#endif

#ifdef RODON_HAS_WINSPARKLE && defined(IS_PRODUCTION)
#include "windows/WinUpdater.h"
#endif

int main(int argc, char *argv[]) {
  QGuiApplication app(argc, argv);
  app.setApplicationVersion(APP_VERSION);
  app.setOrganizationName("Rodon");
  app.setOrganizationDomain("rodon.vpn");
  app.setApplicationName("RodON");

#if defined(Q_OS_MACOS) || defined(Q_OS_WIN) || defined(Q_OS_LINUX)
  QLockFile lock(QDir::temp().absoluteFilePath("com.rodon.vpn.app.lock"));
  lock.setStaleLockTime(0);
  if (!lock.tryLock(100))
    return 0;
#endif

  TranslationManager translationManager(&app);
  QQmlApplicationEngine engine;
  AuthController authController(&engine);
  translationManager.setEngine(&engine);
  RodonController rodon(&authController, &engine);
  engine.rootContext()->setContextProperty("translationManager",
                                           &translationManager);
  engine.rootContext()->setContextProperty("rodon", &rodon);
  engine.rootContext()->setContextProperty("authController", &authController);
  engine.rootContext()->setContextProperty("is_production", IS_PRODUCTION);
  // qDebug() << "RODON_URL" << RODON_URL << IS_PRODUCTION;

  QObject::connect(
      &engine, &QQmlApplicationEngine::objectCreationFailed, &app,
      []() { QCoreApplication::exit(-1); }, Qt::QueuedConnection);
  auto connectionController = rodon.connectionController();
  QObject::connect(&app, &QGuiApplication::aboutToQuit,
                   [connectionController, &rodon]() {
                     connectionController->disconnect(
                         rodon.deviceController()->currentDeviceId());
                     connectionController->stopTunnel();
                   });

  QObject::connect(&app, &QGuiApplication::applicationStateChanged,
                   [connectionController](Qt::ApplicationState state) {
                     if (state == Qt::ApplicationActive) {
                       connectionController->refreshStatus();
                     }
                   });

#ifdef Q_OS_MACOS
  qmlRegisterSingletonInstance("RodON", 1, 0, "SysExt",
                               SystemExtensionManager::instance());
  SystemExtensionManager::instance()->activate();
#endif
  engine.loadFromModule("SVPN", "Main");

#if defined(Q_OS_MACOS) && defined(RODON_HAS_SPARKLE)
  if (RODON_HAS_SPARKLE == 1) {
    SparkleUpdater::instance()->checkForUpdates();
  }
#endif

#if defined(Q_OS_WINDOWS) && defined(RODON_HAS_WINSPARKLE)
  WinUpdater winUpdater;
  winUpdater.checkForUpdates();
#endif

  return app.exec();
}
