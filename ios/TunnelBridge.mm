#include "TunnelBridge.h"
#import <Foundation/Foundation.h>
#import <NetworkExtension/NetworkExtension.h>

TunnelBridge::TunnelBridge(QObject *parent) : QObject(parent) {}

TunnelBridge::~TunnelBridge() {
  if (m_observer) {
    [[NSNotificationCenter defaultCenter]
        removeObserver:(__bridge_transfer id)m_observer];
    m_observer = nullptr;
  }
}

void TunnelBridge::start(const QString &serverPublicKey,
                         const QString &endpoint, const QString &assignedIp,
                         const QString &dns) {
  NSString *pubKey = serverPublicKey.toNSString();
  NSString *ep = endpoint.toNSString();
  NSString *ip = assignedIp.toNSString();
  NSString *dnsStr = dns.toNSString();

  [NETunnelProviderManager loadAllFromPreferencesWithCompletionHandler:^(
                               NSArray<NETunnelProviderManager *> *managers,
                               NSError *error) {
    if (error) {
      emit this->failed(QString::fromNSString(error.localizedDescription));
      return;
    }

    NETunnelProviderManager *mgr = (managers.count > 0)
                                       ? managers.firstObject
                                       : [[NETunnelProviderManager alloc] init];

    NETunnelProviderProtocol *proto = [[NETunnelProviderProtocol alloc] init];
    proto.providerBundleIdentifier = @"com.rodon.vpn.app.tunnel";
    proto.serverAddress = ep; // shown in Settings; also passed to extension
    proto.providerConfiguration = @{
      @"serverPublicKey" : pubKey,
      @"endpoint" : ep,
      @"assignedIp" : ip,
      @"dns" : dnsStr
    };
    // Private key is NOT here — the extension reads it from the shared
    // Keychain.

    mgr.protocolConfiguration = proto;
    mgr.localizedDescription = @"RodON";
    mgr.enabled = YES;

    [mgr saveToPreferencesWithCompletionHandler:^(NSError *saveErr) {
      if (saveErr) {
        emit this->failed(QString::fromNSString(saveErr.localizedDescription));
        return;
      }
      // Reload before starting (Apple's required dance).
      [mgr loadFromPreferencesWithCompletionHandler:^(NSError *loadErr) {
        if (loadErr) {
          emit this->failed(
              QString::fromNSString(loadErr.localizedDescription));
          return;
        }

        // Observe status changes.
        this->m_observer =
            (__bridge_retained void *)[[NSNotificationCenter defaultCenter]
                addObserverForName:NEVPNStatusDidChangeNotification
                            object:mgr.connection
                             queue:[NSOperationQueue mainQueue]
                        usingBlock:^(NSNotification *note) {
                          switch (mgr.connection.status) {
                          case NEVPNStatusConnected:
                            emit this->connected();
                            break;
                          case NEVPNStatusDisconnected:
                            emit this->disconnected();
                            break;
                          case NEVPNStatusInvalid:
                            emit this->failed(
                                QStringLiteral("VPN configuration invalid"));
                            break;
                          default:
                            break; // Connecting / Reasserting / Disconnecting
                          }
                        }];

        NSError *startErr = nil;
        [mgr.connection startVPNTunnelAndReturnError:&startErr];
        if (startErr) {
          emit this->failed(
              QString::fromNSString(startErr.localizedDescription));
        }
      }];
    }];
  }];
}

void TunnelBridge::stop() {
  [NETunnelProviderManager
      loadAllFromPreferencesWithCompletionHandler:^(
          NSArray<NETunnelProviderManager *> *managers, NSError *error) {
        if (managers.count > 0) {
          [managers.firstObject.connection stopVPNTunnel];
        }
        emit this->disconnected();
      }];
}

void TunnelBridge::refreshStatus() {
  [NETunnelProviderManager
      loadAllFromPreferencesWithCompletionHandler:^(
          NSArray<NETunnelProviderManager *> *managers, NSError *error) {
        if (error || managers.count == 0) {
          emit this->disconnected(); // конфігурації нема → точно не підключено
          return;
        }
        NETunnelProviderManager *mgr = managers.firstObject;

        // Поточний стан.
        switch (mgr.connection.status) {
        case NEVPNStatusConnected:
          emit this->connected();
          break;
        case NEVPNStatusConnecting:
        case NEVPNStatusReasserting:
          // проміжний — лишаємо як є або трактуємо як connecting
          break;
        default:
          emit this->disconnected();
          break;
        }

        // Підписка на майбутні зміни (якщо ще не підписані).
        if (!this->m_observer) {
          this->m_observer =
              (__bridge_retained void *)[[NSNotificationCenter defaultCenter]
                  addObserverForName:NEVPNStatusDidChangeNotification
                              object:mgr.connection
                               queue:[NSOperationQueue mainQueue]
                          usingBlock:^(NSNotification *note) {
                            switch (mgr.connection.status) {
                            case NEVPNStatusConnected:
                              emit this->connected();
                              break;
                            case NEVPNStatusDisconnected:
                              emit this->disconnected();
                              break;
                            default:
                              break;
                            }
                          }];
        }
      }];
}
