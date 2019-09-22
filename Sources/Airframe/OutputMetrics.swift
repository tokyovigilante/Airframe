public struct OutputMetrics {
    public var id: Int = -1
    public var physicalWidth: Int = -1
    public var physicalHeight: Int = -1
    public var x: Int = -1
    public var y: Int = -1
    public var make: String = ""
    public var model: String = ""
    public var modeWidth: Int = -1
    public var modeHeight: Int = -1
    public var refresh: Int = -1
    public var scaleFactor: Int = -1

    public var dpi: Int {
        if !valid {
            return -1
        }
        let horizontalRawDPI = calculateDPI(physical: physicalWidth, pixels: modeWidth)
        let verticalRawDPI = calculateDPI(physical: physicalHeight, pixels: modeHeight)
        if horizontalRawDPI == verticalRawDPI {
            return Int(horizontalRawDPI)
        } else {
            return Int((horizontalRawDPI + verticalRawDPI) / 2)
        }
    }
    public var valid: Bool {
        return id != -1 &&
            physicalWidth != -1 &&
            physicalHeight != -1 &&
            x != -1 &&
            y != -1 &&
            !make.isEmpty &&
            !model.isEmpty &&
            modeWidth != -1 &&
            modeHeight != -1 &&
            refresh != -1 &&
            scaleFactor != -1
    }

    private func calculateDPI (physical: Int, pixels: Int) -> Double {
       return Double(pixels) / ((Double(physical) / 10) / 2.54)
    }
}

extension OutputMetrics: Equatable {}

extension OutputMetrics: CustomStringConvertible {

    public var description: String {
        if !valid {
             return "Invalid output metrics"
        }
        let refreshString = String(format: "%.3f Hz", Double(refresh) / 1000)
        return "\(id): \(make) \(model): \(modeWidth)x\(modeHeight) @ \(refreshString) (\(scaleFactor)x) \(dpi)dpi"
    }
}
