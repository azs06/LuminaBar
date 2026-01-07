import Foundation
import Network

@MainActor
@Observable
final class YeelightDevice: Identifiable, Hashable {
    let id: String
    let name: String
    let ip: String
    let port: UInt16
    let model: String

    var power: Bool = false
    var brightness: Int = 100
    var colorTemp: Int = 4000
    var rgb: Int = 16777215
    var colorMode: Int = 2

    private var connection: NWConnection?
    private var commandId: Int = 1
    private var pendingCallbacks: [Int: CheckedContinuation<[String], Error>] = [:]
    private var receiveBuffer = ""

    init(id: String, name: String, ip: String, port: UInt16, model: String) {
        self.id = id
        self.name = name
        self.ip = ip
        self.port = port
        self.model = model
    }

    nonisolated static func == (lhs: YeelightDevice, rhs: YeelightDevice) -> Bool {
        lhs.id == rhs.id
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    var rgbColor: (r: Int, g: Int, b: Int) {
        get {
            let r = (rgb >> 16) & 0xFF
            let g = (rgb >> 8) & 0xFF
            let b = rgb & 0xFF
            return (r, g, b)
        }
        set {
            rgb = (newValue.r << 16) | (newValue.g << 8) | newValue.b
        }
    }

    func connect() {
        guard connection == nil else { return }

        let host = NWEndpoint.Host(ip)
        let port = NWEndpoint.Port(rawValue: self.port)!

        connection = NWConnection(host: host, port: port, using: .tcp)
        connection?.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                switch state {
                case .ready:
                    self?.startReceiving()
                case .failed, .cancelled:
                    self?.connection = nil
                default:
                    break
                }
            }
        }
        connection?.start(queue: .main)
    }

    func disconnect() {
        connection?.cancel()
        connection = nil
    }

    private func startReceiving() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, _, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                if let data = data, let str = String(data: data, encoding: .utf8) {
                    self.receiveBuffer += str
                    self.processBuffer()
                }

                if error == nil {
                    self.startReceiving()
                }
            }
        }
    }

    private func processBuffer() {
        while let range = receiveBuffer.range(of: "\r\n") {
            let line = String(receiveBuffer[..<range.lowerBound])
            receiveBuffer = String(receiveBuffer[range.upperBound...])

            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }

            if let id = json["id"] as? Int {
                if let result = json["result"] as? [String] {
                    pendingCallbacks[id]?.resume(returning: result)
                    pendingCallbacks.removeValue(forKey: id)
                } else if let error = json["error"] as? [String: Any],
                          let message = error["message"] as? String {
                    pendingCallbacks[id]?.resume(throwing: YeelightError.commandFailed(message))
                    pendingCallbacks.removeValue(forKey: id)
                } else {
                    // Some commands return ["ok"] or empty result
                    pendingCallbacks[id]?.resume(returning: ["ok"])
                    pendingCallbacks.removeValue(forKey: id)
                }
            } else if json["method"] as? String == "props",
                      let params = json["params"] as? [String: Any] {
                updateFromParams(params)
            }
        }
    }

    private func updateFromParams(_ params: [String: Any]) {
        if let power = params["power"] as? String {
            self.power = power == "on"
        }
        if let bright = params["bright"] as? String, let val = Int(bright) {
            self.brightness = val
        }
        if let ct = params["ct"] as? String, let val = Int(ct) {
            self.colorTemp = val
        }
        if let rgb = params["rgb"] as? String, let val = Int(rgb) {
            self.rgb = val
        }
        if let colorMode = params["color_mode"] as? String, let val = Int(colorMode) {
            self.colorMode = val
        }
    }

    private func sendCommand(_ method: String, params: [Any]) async throws -> [String] {
        if connection == nil {
            connect()
            try await Task.sleep(for: .milliseconds(500))
        }

        guard let connection = connection else {
            throw YeelightError.notConnected
        }

        let id = commandId
        commandId += 1

        let command: [String: Any] = ["id": id, "method": method, "params": params]
        guard let data = try? JSONSerialization.data(withJSONObject: command),
              var str = String(data: data, encoding: .utf8) else {
            throw YeelightError.encodingFailed
        }
        str += "\r\n"

        return try await withCheckedThrowingContinuation { continuation in
            pendingCallbacks[id] = continuation

            connection.send(content: str.data(using: .utf8), completion: .contentProcessed { [weak self] error in
                if let error = error {
                    Task { @MainActor [weak self] in
                        self?.pendingCallbacks.removeValue(forKey: id)
                    }
                    continuation.resume(throwing: error)
                }
            })

            // Timeout after 5 seconds
            Task { [weak self] in
                try await Task.sleep(for: .seconds(5))
                await MainActor.run {
                    if self?.pendingCallbacks[id] != nil {
                        self?.pendingCallbacks.removeValue(forKey: id)
                        continuation.resume(throwing: YeelightError.timeout)
                    }
                }
            }
        }
    }

    func setPower(_ on: Bool) async throws {
        _ = try await sendCommand("set_power", params: [on ? "on" : "off", "smooth", 300])
        self.power = on
    }

    func setBrightness(_ value: Int) async throws {
        let clamped = max(1, min(100, value))
        _ = try await sendCommand("set_bright", params: [clamped, "smooth", 300])
        self.brightness = clamped
    }

    func setColorTemperature(_ value: Int) async throws {
        let clamped = max(1700, min(6500, value))
        _ = try await sendCommand("set_ct_abx", params: [clamped, "smooth", 300])
        self.colorTemp = clamped
        self.colorMode = 2
    }

    func setRGB(_ r: Int, _ g: Int, _ b: Int) async throws {
        let rgb = (max(0, min(255, r)) << 16) | (max(0, min(255, g)) << 8) | max(0, min(255, b))
        _ = try await sendCommand("set_rgb", params: [rgb, "smooth", 300])
        self.rgb = rgb
        self.colorMode = 1
    }

    func refreshState() async throws {
        let result = try await sendCommand("get_prop", params: ["power", "bright", "ct", "rgb", "color_mode"])
        if result.count >= 5 {
            self.power = result[0] == "on"
            self.brightness = Int(result[1]) ?? 100
            self.colorTemp = Int(result[2]) ?? 4000
            self.rgb = Int(result[3]) ?? 16777215
            self.colorMode = Int(result[4]) ?? 2
        }
    }
}

enum YeelightError: LocalizedError {
    case notConnected
    case encodingFailed
    case timeout
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .notConnected: return "Not connected to device"
        case .encodingFailed: return "Failed to encode command"
        case .timeout: return "Command timed out"
        case .commandFailed(let msg): return msg
        }
    }
}
