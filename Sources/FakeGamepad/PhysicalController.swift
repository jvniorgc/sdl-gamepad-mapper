import Foundation
import IOKit
import IOKit.hid

/// Reads HID reports from the physical 8BitDo controller
final class PhysicalController {
    
    struct Report: Equatable {
        var buttons: UInt16     // 15 buttons in bits 0-14
        var hatSwitch: UInt8    // 0-7 direction, 0x0F = neutral
        var leftStickX: UInt8   // 0-255, center ~128
        var leftStickY: UInt8
        var rightStickX: UInt8
        var rightStickY: UInt8
        var leftTrigger: UInt8  // 0-255
        var rightTrigger: UInt8
        
        static let neutral = Report(
            buttons: 0, hatSwitch: 0x0F,
            leftStickX: 128, leftStickY: 128,
            rightStickX: 128, rightStickY: 128,
            leftTrigger: 0, rightTrigger: 0
        )
        
        var pressedButtonIndices: [Int] {
            (0..<15).filter { buttons & (1 << $0) != 0 }
        }
    }
    
    static let vendorID: Int = 0x2DC8
    static let productID: Int = 0x301D
    
    private var manager: IOHIDManager?
    private var reportBuffer = [UInt8](repeating: 0, count: 64)
    
    var onReport: ((Report) -> Void)?
    var onConnect: (() -> Void)?
    var onDisconnect: (() -> Void)?
    
    func start() -> Bool {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        self.manager = manager
        
        let matchingDict: [String: Any] = [
            kIOHIDVendorIDKey as String: PhysicalController.vendorID,
            kIOHIDProductIDKey as String: PhysicalController.productID,
        ]
        
        IOHIDManagerSetDeviceMatching(manager, matchingDict as CFDictionary)
        
        let context = Unmanaged.passUnretained(self).toOpaque()
        
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { ctx, _, _, device in
            guard let ctx else { return }
            let self_ = Unmanaged<PhysicalController>.fromOpaque(ctx).takeUnretainedValue()
            self_.deviceConnected(device)
        }, context)
        
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { ctx, _, _, _ in
            guard let ctx else { return }
            let self_ = Unmanaged<PhysicalController>.fromOpaque(ctx).takeUnretainedValue()
            self_.onDisconnect?()
        }, context)
        
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        
        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else {
            print("❌ Failed to open HID Manager: \(String(format: "0x%x", result))")
            return false
        }
        return true
    }
    
    private func deviceConnected(_ device: IOHIDDevice) {
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDDeviceRegisterInputReportCallback(
            device, &reportBuffer, reportBuffer.count,
            { ctx, _, _, _, reportID, report, length in
                guard let ctx else { return }
                let self_ = Unmanaged<PhysicalController>.fromOpaque(ctx).takeUnretainedValue()
                self_.handleInputReport(reportID: reportID, report: report, length: length)
            },
            context
        )
        onConnect?()
    }
    
    private func handleInputReport(reportID: UInt32, report: UnsafeMutablePointer<UInt8>, length: CFIndex) {
        guard reportID == 1, length >= 9 else { return }
        let parsed = Report(
            buttons: UInt16(report[0]) | (UInt16(report[1]) << 8),
            hatSwitch: report[2] & 0x0F,
            leftStickX: report[3],
            leftStickY: report[4],
            rightStickX: report[5],
            rightStickY: report[6],
            leftTrigger: report[7],
            rightTrigger: report[8]
        )
        onReport?(parsed)
    }
    
    func stop() {
        if let manager {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        }
        manager = nil
    }
}
