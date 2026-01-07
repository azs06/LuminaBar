import Foundation
import Network

@MainActor
@Observable
final class YeelightManager {
    static let shared = YeelightManager()

    var devices: [YeelightDevice] = []
    var isDiscovering = false

    private let multicastGroup = "239.255.255.250"
    private let multicastPort: UInt16 = 1982

    private init() {}

    func discover() async {
        guard !isDiscovering else { return }
        isDiscovering = true

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            discoverDevices {
                Task { @MainActor in
                    self.isDiscovering = false
                    continuation.resume()
                }
            }
        }
    }

    private nonisolated func discoverDevices(completion: @escaping @Sendable () -> Void) {
        let message = """
        M-SEARCH * HTTP/1.1\r
        HOST: \(multicastGroup):\(multicastPort)\r
        MAN: "ssdp:discover"\r
        ST: wifi_bulb\r
        \r

        """

        guard let socket = try? NWConnectionGroup(
            with: NWMulticastGroup(for: [.hostPort(host: NWEndpoint.Host(multicastGroup), port: NWEndpoint.Port(rawValue: multicastPort)!)]),
            using: .udp
        ) else {
            completion()
            return
        }

        socket.setReceiveHandler(maximumMessageSize: 4096, rejectOversizedMessages: true) { [weak self] message, content, isComplete in
            guard let data = content, let response = String(data: data, encoding: .utf8) else { return }
            if let deviceInfo = self?.parseDiscoveryResponse(response) {
                Task { @MainActor in
                    guard let self = self else { return }
                    if !self.devices.contains(where: { $0.id == deviceInfo.id }) {
                        let device = YeelightDevice(
                            id: deviceInfo.id,
                            name: deviceInfo.name,
                            ip: deviceInfo.ip,
                            port: deviceInfo.port,
                            model: deviceInfo.model
                        )
                        device.power = deviceInfo.power
                        device.brightness = deviceInfo.brightness
                        device.colorTemp = deviceInfo.colorTemp
                        device.rgb = deviceInfo.rgb
                        device.colorMode = deviceInfo.colorMode
                        self.devices.append(device)
                    }
                }
            }
        }

        socket.stateUpdateHandler = { state in
            if case .ready = state {
                socket.send(content: message.data(using: .utf8)) { error in
                    if let error = error {
                        print("Send error: \(error)")
                    }
                }
            }
        }

        socket.start(queue: .main)

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            socket.cancel()
            completion()
        }
    }

    private nonisolated func parseDiscoveryResponse(_ response: String) -> DeviceInfo? {
        var headers: [String: String] = [:]

        for line in response.components(separatedBy: "\r\n") {
            if let colonIndex = line.firstIndex(of: ":") {
                let key = String(line[..<colonIndex]).trimmingCharacters(in: .whitespaces).lowercased()
                let value = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                headers[key] = value
            }
        }

        guard let id = headers["id"],
              let location = headers["location"],
              let match = location.range(of: #"yeelight://([^:]+):(\d+)"#, options: .regularExpression) else {
            return nil
        }

        let locationStr = String(location[match])
        let parts = locationStr.replacingOccurrences(of: "yeelight://", with: "").split(separator: ":")
        guard parts.count == 2,
              let port = UInt16(parts[1]) else {
            return nil
        }

        let ip = String(parts[0])
        let name = headers["name"] ?? "Yeelight \(headers["model"] ?? "Bulb")"
        let model = headers["model"] ?? "unknown"

        return DeviceInfo(
            id: id,
            name: name,
            ip: ip,
            port: port,
            model: model,
            power: headers["power"] == "on",
            brightness: Int(headers["bright"] ?? "100") ?? 100,
            colorTemp: Int(headers["ct"] ?? "4000") ?? 4000,
            rgb: Int(headers["rgb"] ?? "16777215") ?? 16777215,
            colorMode: Int(headers["color_mode"] ?? "2") ?? 2
        )
    }

    func device(byId id: String) -> YeelightDevice? {
        devices.first { $0.id == id }
    }
}

// Intermediate struct for passing device data between threads
private struct DeviceInfo: Sendable {
    let id: String
    let name: String
    let ip: String
    let port: UInt16
    let model: String
    let power: Bool
    let brightness: Int
    let colorTemp: Int
    let rgb: Int
    let colorMode: Int
}
