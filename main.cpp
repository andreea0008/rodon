#include "ConnectionController.h"
#include "RodonController.h"
#include "Utils.h"
#include "source/TranslationManager.h"
#include <AuthController.h>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>

int main(int argc, char *argv[]) {
  QGuiApplication app(argc, argv);
  app.setApplicationVersion(APP_VERSION);
  TranslationManager translationManager(&app);
  QQmlApplicationEngine engine;
  AuthController authController(&engine);
  translationManager.setEngine(&engine);
  RodonController rodon(&authController, &engine);
  qDebug() << "RODON_URL" << RODON_URL;
  engine.rootContext()->setContextProperty("translationManager",
                                           &translationManager);
  engine.rootContext()->setContextProperty("rodon", &rodon);
  engine.rootContext()->setContextProperty("authController", &authController);

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

  engine.loadFromModule("SVPN", "Main");
  return app.exec();
}
