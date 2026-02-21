import UIKit

enum OwnerBypass {
    /// The device identifierForVendor UUID of the owner's device.
    ///
    /// To find your device UUID:
    /// 1. Run the app on your device
    /// 2. Check the Xcode console for "Device UUID: ..."
    /// 3. Paste it here
    ///
    /// This value persists across app updates but changes on reinstall.
    private static let ownerDeviceID = "B39B3D49-AEED-4ECE-863F-1664F7680799"

    /// Set to false to disable bypass (e.g., for App Store review builds)
    private static let bypassEnabled = true

    static var isOwnerDevice: Bool {
        guard bypassEnabled else { return false }
        guard let deviceID = UIDevice.current.identifierForVendor?.uuidString else {
            return false
        }
        return deviceID == ownerDeviceID
    }

    /// Call this once at app launch to print the device UUID to the console
    static func printDeviceUUID() {
        #if DEBUG
        if let uuid = UIDevice.current.identifierForVendor?.uuidString {
            print("📱 Device UUID: \(uuid)")
        }
        #endif
    }
}
