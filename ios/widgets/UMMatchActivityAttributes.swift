//
//  UMMatchActivityAttributes.swift
//  widgets (widgetsExtension target)
//
//  ⚠️ 必须与 Runner 目标里 AppDelegate.swift 中的同名 struct 保持「逐字段一致」。
//  ActivityKit 跨进程通过 String(describing:) 的非限定类型名匹配 Activity 与
//  其 ActivityConfiguration，故两个 target 各有一份相同定义即可（无需共享文件）。
//

import ActivityKit
import Foundation

@available(iOS 16.1, *)
struct UMMatchActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var statusText: String
    }

    var home: String
    var away: String
    var comp: String
    var kickoffEpoch: Double
}
