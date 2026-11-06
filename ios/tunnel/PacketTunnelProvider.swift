import NetworkExtension
import WireGuardKitC
import os

// WireGuardKit sources are compiled into this target, so no `import WireGuardKit`
// — its types (WireGuardAdapter, TunnelConfiguration, PrivateKey, etc.) are part
// of this module directly. WireGuardKitC is imported for the C layer.

class PacketTunnelProvider: NEPacketTunnelProvider {
    private var watchdog: DispatchSourceTimer?
    private lazy var adapter: WireGuardAdapter = {
        WireGuardAdapter(with: self) { _, message in
            os_log("wg: %{public}s", message)
        }
    }()

    override func startTunnel(options: [String : NSObject]?,
                             completionHandler: @escaping (Error?) -> Void) {
        os_log("RodonTunnel: startTunnel called")
        let fromApp = (options?["source"] as? String) == "app"
        os_log("RodonTunnel: startTunnel source=%{public}@", fromApp ? "app" : "system")


        guard let proto = protocolConfiguration as? NETunnelProviderProtocol,
              let conf = proto.providerConfiguration,
              let endpoint = conf["endpoint"] as? String,
              let serverPubKey = conf["serverPublicKey"] as? String,
              let assignedIp = conf["assignedIp"] as? String,
              let dns = conf["dns"] as? String else {
            os_log("RodonTunnel: missing providerConfiguration")
            completionHandler(NSError(domain: "Rodon", code: 1))
            return
        }
        
        let privKeyBase64 = (conf["privateKey"] as? String) ?? KeychainBridge.loadPrivateKey()
        guard let privKeyBase64,
              let privateKey = PrivateKey(base64Key: privKeyBase64),
              let serverKey = PublicKey(base64Key: serverPubKey) else {
            os_log("RodonTunnel: missing or invalid keys (privKey present: %{public}d)",
                  (conf["privateKey"] as? String) != nil ? 1 : 0)
            completionHandler(NSError(domain: "Rodon", code: 2))
            return
        }
        

        var interface = InterfaceConfiguration(privateKey: privateKey)
        if let addr = IPAddressRange(from: assignedIp) {
            interface.addresses = [addr]
        }
        if let dnsServer = DNSServer(from: dns) {
            interface.dns = [dnsServer]
        }

        var peer = PeerConfiguration(publicKey: serverKey)
        peer.endpoint = Endpoint(from: endpoint)
        peer.allowedIPs = [IPAddressRange(from: "0.0.0.0/0")!]
        peer.persistentKeepAlive = 25

        let wgConfig = TunnelConfiguration(name: "RodON",
                                          interface: interface,
                                          peers: [peer])

        if !fromApp, (conf["allowSystemStart"] as? Bool) == false {
            completionHandler(NSError(domain: "Rodon", code: 4,
              userInfo: [NSLocalizedDescriptionKey: "Open RodON to connect"]))
             return
            }

        adapter.start(tunnelConfiguration: wgConfig) { [weak self] error in
          if let error {
              os_log("RodonTunnel: adapter error: %{public}@", String(describing: error))
          } else {
              os_log("RodonTunnel: tunnel up")
              self?.startHandshakeWatchdog()
           }
          completionHandler(error)
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason,
                            completionHandler: @escaping () -> Void) {
        os_log("RodonTunnel: stopTunnel called")
        stopWatchdog()
        adapter.stop { error in
            if let error {
                os_log("RodonTunnel: adapter stop error: %{public}@",
                       String(describing: error))
            }
            completionHandler()
            #if os(macOS)
                exit(0)
            #endif
        }
    }

    private func startHandshakeWatchdog(timeout: TimeInterval = 20) {
        let started = Date()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 3, repeating: 3)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            self.adapter.getRuntimeConfiguration { uapi in
                let handshake = uapi.map(Self.lastHandshakeSec) ?? 0
                DispatchQueue.main.async {
                    if handshake > 0 {
                        os_log("RodonTunnel: handshake ok")
                        self.stopWatchdog()
                    } else if Date().timeIntervalSince(started) > timeout {
                        os_log("RodonTunnel: no handshake in %{public}d s, cancelling", Int(timeout))
                        self.stopWatchdog()
                        self.cancelTunnelWithError(NSError(domain: "Rodon", code: 3,
                            userInfo: [NSLocalizedDescriptionKey: "Server is not responding"]))
                    }
                }
            }
        }
        watchdog = timer
        timer.resume()
    }

    private func stopWatchdog() {
        watchdog?.cancel()
        watchdog = nil
    }

    private static func lastHandshakeSec(_ uapi: String) -> Int {
        let prefix = "last_handshake_time_sec="
        for line in uapi.split(separator: "\n") where line.hasPrefix(prefix) {
            return Int(line.dropFirst(prefix.count)) ?? 0
        }
        return 0
    }
}
