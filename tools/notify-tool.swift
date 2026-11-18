// 測試工具：發送一個「分散式通知」（DistributedNotification）
// 用法： notify-tool com.apple.screenIsLocked
import Foundation

guard CommandLine.arguments.count > 1 else {
    print("用法：notify-tool <通知名稱>")
    exit(1)
}
let name = Notification.Name(CommandLine.arguments[1])
DistributedNotificationCenter.default().postNotificationName(name, object: nil, userInfo: nil, deliverImmediately: true)
print("已發送分散式通知：\(name.rawValue)")
Thread.sleep(forTimeInterval: 0.5)
