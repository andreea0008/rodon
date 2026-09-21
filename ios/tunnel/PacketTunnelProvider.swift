import NetworkExtension
import WireGuardKitC
import os

// WireGuardKit sources are compiled into this target, so no `import WireGuardKit`
// — its types (WireGuardAdapter, TunnelConfiguration, PrivateKey, etc.) are part
// of this module directly. WireGuardKitC is imported for the C layer.

class PacketTunnelProvider: NEPacketTunnelProvider {
    private lazy var adapter: WireGuardAdapter = {
        WireGuardAdapter(with: self) { _, message in
            os_log("wg: %{public}s", message)
        }
    }()

    override func startTunnel(options: [String : NSObject]?,
                             completionHandler: @escaping (Error?) -> Void) {
        os_log("RodonTunnel: startTunnel called")

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

        guard let privKeyBase64 = KeychainBridge.loadPrivateKey(),
              let privateKey = PrivateKey(base64Key: privKeyBase64),
              let serverKey = PublicKey(base64Key: serverPubKey) else {
            os_log("RodonTunnel: missing or invalid keys")
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

        adapter.start(tunnelConfiguration: wgConfig) { error in
            if let error = error {
                os_log("RodonTunnel: adapter error: %{public}@",
                       String(describing: error))
            } else {
                os_log("RodonTunnel: tunnel up")
            }
            completionHandler(error)
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason,
                            completionHandler: @escaping () -> Void) {
        os_log("RodonTunnel: stopTunnel called")
        adapter.stop { _ in completionHandler() }
    }
}
