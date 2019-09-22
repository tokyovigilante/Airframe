import Foundation

public protocol AirframeWindow {
    var width: Int { get }
    var height: Int { get }
    var title: String? { get set }
    var appID: String? { get }
    var scaleFactor: Double { get }

    var pixelWidth: Int { get }
    var pixelHeight: Int { get }

    init? (title: String?, appID: String?,
        width: Int, height: Int, scaleFactor: Double)
}

extension AirframeWindow {

    public var pixelWidth: Int {
        return Int(Double(width) * scaleFactor)
    }

    public var pixelHeight: Int {
        return Int(Double(height) * scaleFactor)
    }
}
