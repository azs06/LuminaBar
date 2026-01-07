import SwiftUI
import AppKit

struct DeviceCardView: View {
    @Bindable var device: YeelightDevice
    @State private var isLoading = false
    @State private var localBrightness: Double = 100
    @State private var localColorTemp: Double = 4000
    @State private var localColor: Color = .white

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow

            if device.power {
                controls
            }
        }
        .padding(12)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .animation(.easeInOut(duration: 0.2), value: device.power)
        .onAppear {
            syncLocalState()
        }
        .onChange(of: device.brightness) { _, new in
            localBrightness = Double(new)
        }
        .onChange(of: device.colorTemp) { _, new in
            localColorTemp = Double(new)
        }
        .onChange(of: device.rgb) { _, new in
            let (r, g, b) = device.rgbColor
            localColor = Color(red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255)
        }
    }

    private var headerRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.system(.subheadline, weight: .medium))
                Text(device.model.uppercased())
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Button {
                togglePower()
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(device.power ? .white : .secondary)
                    .frame(width: 32, height: 32)
                    .background(device.power ? Color.orange : Color.clear)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .strokeBorder(device.power ? Color.clear : Color.secondary.opacity(0.3), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
        }
    }

    private var controls: some View {
        VStack(spacing: 14) {
            controlRow(
                icon: "sun.max.fill",
                label: "Brightness",
                value: "\(Int(localBrightness))%"
            ) {
                Slider(value: $localBrightness, in: 1...100, step: 1) { editing in
                    if !editing {
                        setBrightness()
                    }
                }
                .tint(localColor)
            }

            controlRow(
                icon: "thermometer.medium",
                label: "Temperature",
                value: "\(Int(localColorTemp))K"
            ) {
                Slider(value: $localColorTemp, in: 1700...6500, step: 100) { editing in
                    if !editing {
                        setColorTemp()
                    }
                }
                .tint(temperatureGradient)
            }

            // Color section
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text("Color")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    // Native color well - opens system color panel
                    ColorWellView(color: $localColor) {
                        setRGB()
                    }
                    .frame(width: 32, height: 24)

                    Spacer()
                        .frame(width: 8)

                    // Preset colors
                    ForEach(presetColors, id: \.self) { color in
                        Button {
                            localColor = color
                            setRGB()
                        } label: {
                            Circle()
                                .fill(color)
                                .frame(width: 22, height: 22)
                                .overlay(
                                    Circle()
                                        .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func controlRow<Content: View>(
        icon: String,
        label: String,
        value: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                if let value = value {
                    Spacer()
                    Text(value)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            content()
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(.background)
            .shadow(color: device.power ? glowColor.opacity(0.3) : .clear, radius: 8)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.quaternary, lineWidth: 1)
            )
    }

    private var glowColor: Color {
        if device.colorMode == 1 {
            let (r, g, b) = device.rgbColor
            return Color(red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255)
        } else {
            return .orange
        }
    }

    private var temperatureGradient: LinearGradient {
        LinearGradient(
            colors: [.orange, .white, .cyan],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var presetColors: [Color] {
        [.red, .orange, .yellow, .green, .cyan, .blue, .purple]
    }

    private func syncLocalState() {
        localBrightness = Double(device.brightness)
        localColorTemp = Double(device.colorTemp)
        let (r, g, b) = device.rgbColor
        localColor = Color(red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255)
    }

    private func togglePower() {
        isLoading = true
        Task {
            try? await device.setPower(!device.power)
            isLoading = false
        }
    }

    private func setBrightness() {
        Task {
            try? await device.setBrightness(Int(localBrightness))
        }
    }

    private func setColorTemp() {
        Task {
            try? await device.setColorTemperature(Int(localColorTemp))
        }
    }

    private func setRGB() {
        Task {
            let resolved = localColor.resolve(in: EnvironmentValues())
            let r = Int(resolved.red * 255)
            let g = Int(resolved.green * 255)
            let b = Int(resolved.blue * 255)
            try? await device.setRGB(r, g, b)
        }
    }
}

// MARK: - NSColorWell wrapper for SwiftUI
struct ColorWellView: NSViewRepresentable {
    @Binding var color: Color
    var onChange: () -> Void

    func makeNSView(context: Context) -> NSColorWell {
        let colorWell = NSColorWell(frame: .zero)
        colorWell.colorWellStyle = .minimal
        colorWell.target = context.coordinator
        colorWell.action = #selector(Coordinator.colorChanged(_:))
        return colorWell
    }

    func updateNSView(_ nsView: NSColorWell, context: Context) {
        let resolved = color.resolve(in: EnvironmentValues())
        nsView.color = NSColor(
            red: CGFloat(resolved.red),
            green: CGFloat(resolved.green),
            blue: CGFloat(resolved.blue),
            alpha: 1.0
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        var parent: ColorWellView

        init(_ parent: ColorWellView) {
            self.parent = parent
        }

        @objc func colorChanged(_ sender: NSColorWell) {
            // Convert to sRGB for consistent values
            let nsColor = sender.color.usingColorSpace(.sRGB) ?? sender.color
            parent.color = Color(
                red: nsColor.redComponent,
                green: nsColor.greenComponent,
                blue: nsColor.blueComponent
            )
            parent.onChange()
        }
    }
}
