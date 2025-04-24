import Foundation
import UIKit

struct DeviceInfo: Codable {
    let udid: String
    let deviceName: String
    let deviceModel: String
    let iosVersion: String
    
    static func current() -> DeviceInfo {
        // Get the real device identifier
        let deviceName = UIDevice.current.name
        let deviceModel = UIDevice.modelName // Raw device identifier
        let iosVersion = UIDevice.current.systemVersion
        
        // Create a string with device info
        let deviceInfoString = "\(deviceName)-\(deviceModel)-\(iosVersion)-\(Date().timeIntervalSince1970)"
        
        // Hash the string to create a pseudo-UDID
        let pseudoUDID = deviceInfoString.hashValue.magnitude.description
        
        return DeviceInfo(
            udid: pseudoUDID,
            deviceName: deviceName,
            deviceModel: deviceModel, // Using the raw device identifier
            iosVersion: iosVersion
        )
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "udid": udid,
            "device_name": deviceName,
            "device_model": deviceModel,
            "ios_version": iosVersion
        ]
    }
}

// Extension to get the device model name
extension UIDevice {
    static var modelName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        
        // Always return the raw identifier for accurate device identification
        return identifier
    }
    
    // Helper method to get a user-friendly device name
    static var marketingName: String {
        let identifier = modelName
        
        // Map common device identifiers to human-readable names
        switch identifier {
        case "iPhone8,1": return "iPhone 6s"
        case "iPhone8,2": return "iPhone 6s Plus"
        case "iPhone9,1", "iPhone9,3": return "iPhone 7"
        case "iPhone9,2", "iPhone9,4": return "iPhone 7 Plus"
        case "iPhone10,1", "iPhone10,4": return "iPhone 8"
        case "iPhone10,2", "iPhone10,5": return "iPhone 8 Plus"
        case "iPhone10,3", "iPhone10,6": return "iPhone X"
        case "iPhone11,2": return "iPhone XS"
        case "iPhone11,4", "iPhone11,6": return "iPhone XS Max"
        case "iPhone11,8": return "iPhone XR"
        case "iPhone12,1": return "iPhone 11"
        case "iPhone12,3": return "iPhone 11 Pro"
        case "iPhone12,5": return "iPhone 11 Pro Max"
        case "iPhone13,1": return "iPhone 12 mini"
        case "iPhone13,2": return "iPhone 12"
        case "iPhone13,3": return "iPhone 12 Pro"
        case "iPhone13,4": return "iPhone 12 Pro Max"
        case "iPhone14,4": return "iPhone 13 mini"
        case "iPhone14,5": return "iPhone 13"
        case "iPhone14,2": return "iPhone 13 Pro"
        case "iPhone14,3": return "iPhone 13 Pro Max"
        case "iPhone14,7": return "iPhone 14"
        case "iPhone14,8": return "iPhone 14 Plus"
        case "iPhone15,2": return "iPhone 14 Pro"
        case "iPhone15,3": return "iPhone 14 Pro Max"
        case "iPhone15,4": return "iPhone 15"
        case "iPhone15,5": return "iPhone 15 Plus"
        case "iPhone16,1": return "iPhone 15 Pro"
        case "iPhone16,2": return "iPhone 15 Pro Max"
        case "iPad8,1", "iPad8,2", "iPad8,3", "iPad8,4": return "iPad Pro (11-inch)"
        case "iPad8,5", "iPad8,6", "iPad8,7", "iPad8,8": return "iPad Pro (12.9-inch) (3rd generation)"
        case "iPad8,9", "iPad8,10": return "iPad Pro (11-inch) (2nd generation)"
        case "iPad8,11", "iPad8,12": return "iPad Pro (12.9-inch) (4th generation)"
        case "iPad13,1", "iPad13,2": return "iPad Air (4th generation)"
        case "iPad13,4", "iPad13,5", "iPad13,6", "iPad13,7": return "iPad Pro (11-inch) (3rd generation)"
        case "iPad13,8", "iPad13,9", "iPad13,10", "iPad13,11": return "iPad Pro (12.9-inch) (5th generation)"
        default: return identifier
        }
    }
}