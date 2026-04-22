import Foundation

/// Generates SDL2 Game Controller mapping strings
enum SDLMappingGenerator {
    
    /// SDL2 GUID for macOS HID: bus(03) + 00 + vendorLE + 00 + productLE + 00 + versionLE + 00
    static func generateGUID(vendorID: Int, productID: Int, version: Int = 1) -> String {
        let bus: UInt16 = 3 // USB
        let vid = UInt16(vendorID)
        let pid = UInt16(productID)
        let ver = UInt16(version)
        
        return String(format: "%02x%02x0000%02x%02x0000%02x%02x0000%02x%02x0000",
                       bus & 0xFF, (bus >> 8) & 0xFF,
                       vid & 0xFF, (vid >> 8) & 0xFF,
                       pid & 0xFF, (pid >> 8) & 0xFF,
                       ver & 0xFF, (ver >> 8) & 0xFF)
    }
    
    /// Button mapping from 8BitDo HID bit index → SDL button name
    struct ButtonMapping {
        var a: Int?             // South face button
        var b: Int?             // East face button
        var x: Int?             // West face button
        var y: Int?             // North face button
        var leftshoulder: Int?  // LB
        var rightshoulder: Int? // RB
        var back: Int?          // Select
        var start: Int?         // Start
        var guide: Int?         // Home
        var leftstick: Int?     // L3
        var rightstick: Int?    // R3
    }
    
    /// Axis mapping indices
    struct AxisMapping {
        var leftx: Int      // Axis index for left stick X
        var lefty: Int       // Axis index for left stick Y
        var rightx: Int      // Axis index for right stick X
        var righty: Int      // Axis index for right stick Y
        var lefttrigger: Int  // Axis index for left trigger
        var righttrigger: Int // Axis index for right trigger
    }
    
    /// Generate complete SDL mapping string
    static func generateMapping(
        guid: String,
        name: String,
        buttons: ButtonMapping,
        axes: AxisMapping,
        hatIndex: Int = 0
    ) -> String {
        var parts = ["\(guid)", name]
        
        // Buttons
        if let v = buttons.a             { parts.append("a:b\(v)") }
        if let v = buttons.b             { parts.append("b:b\(v)") }
        if let v = buttons.x             { parts.append("x:b\(v)") }
        if let v = buttons.y             { parts.append("y:b\(v)") }
        if let v = buttons.leftshoulder  { parts.append("leftshoulder:b\(v)") }
        if let v = buttons.rightshoulder { parts.append("rightshoulder:b\(v)") }
        if let v = buttons.back          { parts.append("back:b\(v)") }
        if let v = buttons.start         { parts.append("start:b\(v)") }
        if let v = buttons.guide         { parts.append("guide:b\(v)") }
        if let v = buttons.leftstick     { parts.append("leftstick:b\(v)") }
        if let v = buttons.rightstick    { parts.append("rightstick:b\(v)") }
        
        // Axes
        parts.append("leftx:a\(axes.leftx)")
        parts.append("lefty:a\(axes.lefty)")
        parts.append("rightx:a\(axes.rightx)")
        parts.append("righty:a\(axes.righty)")
        parts.append("lefttrigger:a\(axes.lefttrigger)")
        parts.append("righttrigger:a\(axes.righttrigger)")
        
        // D-Pad as hat switch
        parts.append("dpup:h\(hatIndex).1")
        parts.append("dpright:h\(hatIndex).2")
        parts.append("dpdown:h\(hatIndex).4")
        parts.append("dpleft:h\(hatIndex).8")
        
        // Platform
        parts.append("platform:Mac OS X")
        
        return parts.joined(separator: ",")
    }
    
    /// Default mapping for 8BitDo Ultimate 2C based on standard DInput layout
    static func default8BitDoMapping() -> (ButtonMapping, AxisMapping) {
        // Standard 8BitDo DInput button order (0-indexed):
        //  0: East (B)      1: South (A)     2: (unused?)   3: North (X)
        //  4: West (Y)      5: (unused?)     6: LB           7: RB
        //  8: LT digital    9: RT digital   10: Select      11: Start
        // 12: Home         13: L3           14: R3
        let buttons = ButtonMapping(
            a: 1, b: 0, x: 3, y: 4,
            leftshoulder: 6, rightshoulder: 7,
            back: 10, start: 11, guide: 12,
            leftstick: 13, rightstick: 14
        )
        
        // Axis order as they appear in the HID descriptor:
        // 0: X (Left Stick X), 1: Y (Left Stick Y)
        // 2: Z (Right Stick X), 3: Rz (Right Stick Y)
        // 4: Accelerator (Left Trigger), 5: Brake (Right Trigger)
        let axes = AxisMapping(
            leftx: 0, lefty: 1, rightx: 2, righty: 3,
            lefttrigger: 4, righttrigger: 5
        )
        
        return (buttons, axes)
    }
}
