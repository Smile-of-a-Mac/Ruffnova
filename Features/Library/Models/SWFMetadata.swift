import Foundation

struct SWFMetadata: Codable, Equatable {
    var stageWidth: UInt32
    var stageHeight: UInt32
    var frameRate: Float
    var totalFrames: UInt32
    var swfVersion: UInt8
    var playerVersion: UInt8
    var isActionScript3: Bool
    var updatedAt: Date

    init(
        stageWidth: UInt32 = 0,
        stageHeight: UInt32 = 0,
        frameRate: Float = 0,
        totalFrames: UInt32 = 0,
        swfVersion: UInt8 = 0,
        playerVersion: UInt8 = 0,
        isActionScript3: Bool = false,
        updatedAt: Date = Date()
    ) {
        self.stageWidth = stageWidth
        self.stageHeight = stageHeight
        self.frameRate = frameRate
        self.totalFrames = totalFrames
        self.swfVersion = swfVersion
        self.playerVersion = playerVersion
        self.isActionScript3 = isActionScript3
        self.updatedAt = updatedAt
    }

    var hasStageSize: Bool { stageWidth > 0 && stageHeight > 0 }
    var hasFrameRate: Bool { frameRate > 0 }
    var hasTotalFrames: Bool { totalFrames > 0 }
}
