import Foundation

class FileUtils {
    static func getFileSize(_ url: URL) -> Int64 {
        return try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 ?? 0
    }
    
    static func formatFileSize(_ bytes: Int64) -> String {
        let kb = Double(bytes) / 1024
        let mb = kb / 1024
        let gb = mb / 1024
        
        if gb >= 1 {
            return String(format: "%.2f GB", gb)
        } else if mb >= 1 {
            return String(format: "%.2f MB", mb)
        } else if kb >= 1 {
            return String(format: "%.2f KB", kb)
        } else {
            return "\(bytes) B"
        }
    }
    
    static func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds / 60)
        let secs = Int(seconds.truncatingRemainder(dividingBy: 60))
        
        if mins > 0 {
            return "\(mins)分\(secs)秒"
        } else {
            return "\(secs)秒"
        }
    }
}