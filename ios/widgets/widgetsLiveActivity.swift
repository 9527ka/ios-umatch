//
//  widgetsLiveActivity.swift
//  widgets
//
//  UMatch 灵动岛 / 锁屏实时活动 (Live Activity, iOS 16.1+).
//  倒计时由 kickoffEpoch 派生，用 Text(.timer) 实时跳动。
//

import ActivityKit
import WidgetKit
import SwiftUI

// UMatch brand green (#047857)
private let laGreen = Color(red: 4.0 / 255.0, green: 120.0 / 255.0, blue: 87.0 / 255.0)

@available(iOS 16.1, *)
struct UMMatchLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: UMMatchActivityAttributes.self) { context in
            // 锁屏 / 横幅
            lockScreen(context.attributes)
                .padding(14)
                .activityBackgroundTint(Color.black.opacity(0.55))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let kickoff = Self.kickoffDate(context.attributes)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.home, systemImage: "soccerball")
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .foregroundColor(laGreen)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.attributes.away)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.comp)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Self.countdown(kickoff, size: 26)
                        .frame(maxWidth: .infinity)
                }
            } compactLeading: {
                Image(systemName: "soccerball").foregroundColor(laGreen)
            } compactTrailing: {
                Self.countdown(kickoff, size: 13, compact: true)
                    .frame(maxWidth: 56)
            } minimal: {
                Image(systemName: "soccerball").foregroundColor(laGreen)
            }
            .keylineTint(laGreen)
        }
    }

    @ViewBuilder
    private func lockScreen(_ a: UMMatchActivityAttributes) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Image(systemName: "soccerball").font(.system(size: 11, weight: .bold))
                    Text(a.comp).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                }
                .foregroundColor(laGreen)
                Text("\(a.home) vs \(a.away)")
                    .font(.system(size: 16, weight: .bold))
                    .lineLimit(1)
                    .foregroundColor(.white)
            }
            Spacer(minLength: 8)
            Self.countdown(Self.kickoffDate(a), size: 24)
                .foregroundColor(.white)
        }
    }

    private static func kickoffDate(_ a: UMMatchActivityAttributes) -> Date {
        Date(timeIntervalSince1970: a.kickoffEpoch)
    }

    /// 实时倒计时。与全局一致：>24h 显示天数。
    /// - compact: 紧凑区（灵动岛胶囊）空间极小，>24h 只显示 "Nd"；
    ///   其余区域 >24h 显示 "Nd HH:MM:SS"（天数静态 + .timer 锚定 kickoff-days*24h 实时跳）。
    @ViewBuilder
    private static func countdown(_ kickoff: Date, size: CGFloat, compact: Bool = false) -> some View {
        let remaining = kickoff.timeIntervalSince(Date())
        if remaining <= 0 {
            Text("Kickoff")
                .font(.system(size: size, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.5)
        } else if remaining > 24 * 60 * 60 {
            let days = Int(remaining) / 86400
            if compact {
                Text("\(days)d")
                    .font(.system(size: size, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            } else {
                let shifted = kickoff.addingTimeInterval(-Double(days) * 86400)
                HStack(spacing: 3) {
                    Text("\(days)d")
                    Text(shifted, style: .timer)
                }
                .font(.system(size: size, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            }
        } else {
            Text(kickoff, style: .timer)
                .font(.system(size: size, weight: .bold, design: .rounded))
                .monospacedDigit()
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
    }
}
