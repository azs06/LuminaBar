import SwiftUI

struct PopoverView: View {
    @State private var manager = YeelightManager.shared

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if manager.devices.isEmpty {
                emptyState
            } else {
                deviceList
            }
        }
        .frame(width: 320)
        .background(.ultraThinMaterial)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Lumina")
                    .font(.headline)
                    .fontWeight(.semibold)
                Text("\(manager.devices.count) device\(manager.devices.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                Task { await manager.discover() }
            } label: {
                Group {
                    if manager.isDiscovering {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .frame(width: 16, height: 16)
            }
            .buttonStyle(.borderless)
            .help("Scan for devices")

            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Quit Lumina")
        }
        .padding()
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "lightbulb.slash")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)

            Text("No lights found")
                .font(.headline)

            Text("Make sure your Yeelight has LAN Control enabled")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Scan Network") {
                Task { await manager.discover() }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(manager.isDiscovering)
        }
        .padding(32)
    }

    private var deviceList: some View {
        VStack(spacing: 12) {
            ForEach(manager.devices) { device in
                DeviceCardView(device: device)
            }
        }
        .padding()
    }
}
