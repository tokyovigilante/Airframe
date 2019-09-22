
public enum PointerEventType {
    case null
    case motion
    case button
}

public struct InputPointerEvent {
    public var type: PointerEventType
    public var time: Int
    public var x: Double
    public var y: Double
    public var button: Int
    public var state: Int
    public var modifiers: InputModifier
}

public enum AxisEventType {
    case null
    case motion
}

public enum AxisDirection {
    case vertical
    case horizontal
}

public struct InputAxisEvent {
    public var type: AxisEventType
    public var time: Int
    public var x: Double
    public var y: Double
    public var axis: AxisDirection
    public var value: Double
    public var modifiers: InputModifier
}

public struct InputModifier: OptionSet {
    public var rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public static let control = InputModifier(rawValue: 1 << 0)
    public static let shift   = InputModifier(rawValue: 1 << 1)
    public static let alt     = InputModifier(rawValue: 1 << 2)
    public static let meta    = InputModifier(rawValue: 1 << 3)

    public static let button1  = InputModifier(rawValue: 1 << 20)
    public static let button2  = InputModifier(rawValue: 1 << 21)
    public static let button3  = InputModifier(rawValue: 1 << 22)
    public static let button4  = InputModifier(rawValue: 1 << 23)
    public static let button5  = InputModifier(rawValue: 1 << 24)
}

public struct InputKeyboardEvent {
    public var time: UInt32
    public var keyCode: UInt32
    public var hardwareKeyCode: UInt32
    public var pressed: Bool
    public var modifiers: InputModifier
};
