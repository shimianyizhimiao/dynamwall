// 影片資訊 + 抽一格畫面
// 用法： vidinfo <影片路徑> [抽格時間秒] [輸出圖檔路徑]
import AVFoundation
import Cocoa

func fourCC(_ v: FourCharCode) -> String {
    let bytes = [UInt8((v >> 24) & 0xFF), UInt8((v >> 16) & 0xFF), UInt8((v >> 8) & 0xFF), UInt8(v & 0xFF)]
    return String(bytes: bytes, encoding: .ascii) ?? "?"
}

guard CommandLine.arguments.count > 1 else {
    print("用法：vidinfo <影片路徑> [秒] [輸出圖檔]")
    exit(1)
}
let url = URL(fileURLWithPath: CommandLine.arguments[1])
let asset = AVURLAsset(url: url)
guard let fileSize = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int else { exit(1) }

let sem = DispatchSemaphore(value: 0)
Task {
    do {
        let dur = try await asset.load(.duration)
        let vTracks = try await asset.loadTracks(withMediaType: .video)
        let aTracks = try await asset.loadTracks(withMediaType: .audio)
        print("檔案大小：\(String(format: "%.1f", Double(fileSize ?? 0) / 1_048_576)) MB")
        print("長度：\(Int(CMTimeGetSeconds(dur))) 秒（\(CMTimeGetSeconds(dur))）")
        print("影片軌：\(vTracks.count)　音訊軌：\(aTracks.count)")
        for t in vTracks {
            let size = try await t.load(.naturalSize)
            let tf = try await t.load(.preferredTransform)
            let fps = try await t.load(.nominalFrameRate)
            let fds = try await t.load(.formatDescriptions)
            let shown = size.applying(tf)
            let codecs = fds.map { fourCC(CMFormatDescriptionGetMediaSubType($0)) }.joined(separator: ",")
            print("畫面：\(Int(abs(shown.width))) x \(Int(abs(shown.height)))　fps=\(fps)　編碼=\(codecs)")
        }
        for t in aTracks {
            let fds = try await t.load(.formatDescriptions)
            let codecs = fds.map { fourCC(CMFormatDescriptionGetMediaSubType($0)) }.joined(separator: ",")
            print("音訊編碼：\(codecs)")
        }

        if CommandLine.arguments.count > 3 {
            let gen = AVAssetImageGenerator(asset: asset)
            gen.appliesPreferredTrackTransform = true
            gen.requestedTimeToleranceBefore = .zero
            gen.requestedTimeToleranceAfter = .zero
            let t = CMTime(seconds: Double(CommandLine.arguments[2]) ?? 1, preferredTimescale: 600)
            if let cg = try? await gen.image(at: t).image {
                let rep = NSBitmapImageRep(cgImage: cg)
                if let data = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) {
                    try? data.write(to: URL(fileURLWithPath: CommandLine.arguments[3]))
                    print("已抽出畫面：\(CommandLine.arguments[3])")
                }
            }
        }
    } catch {
        print("讀取失敗：\(error)")
    }
    sem.signal()
}
sem.wait()
