//
//  widgets.swift
//  widgets
//
//  UMatch — Next Match countdown widget.
//  Reads data shared from the Flutter app via App Group `group.com.uu.umatch`
//  (written by the `home_widget` package).
//

import WidgetKit
import SwiftUI

private let appGroupId = "group.com.uu.umatch"

// UMatch brand green (#047857)
private let umGreen = Color(red: 4.0 / 255.0, green: 120.0 / 255.0, blue: 87.0 / 255.0)

struct MatchEntry: TimelineEntry {
    let date: Date
    let hasMatch: Bool
    let home: String
    let away: String
    let comp: String
    let stage: String
    let venue: String
    let kickoff: Date
    // 自定义提醒 (App 内设置后经 App Group 同步)；空字符串表示未自定义
    var customTitle: String = ""
    var customTeam: String = ""
    var logoPath: String = ""
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> MatchEntry {
        MatchEntry(
            date: Date(),
            hasMatch: true,
            home: "Real Madrid",
            away: "Barcelona",
            comp: "UCL",
            stage: "Final",
            venue: "Wembley",
            kickoff: Date().addingTimeInterval(60 * 60 * 50)
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (MatchEntry) -> Void) {
        completion(readEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MatchEntry>) -> Void) {
        let base = readEntry()
        let now = Date()

        guard base.hasMatch && base.kickoff > now else {
            completion(Timeline(entries: [base], policy: .after(now.addingTimeInterval(60 * 60))))
            return
        }

        // 显示 "Nd HH:MM:SS"：天数取整后静态显示，HH:MM:SS 用 `.timer` 实时跳动
        // (锚定到 kickoff - days*24h 的"日内目标")。每跨过一个日界需要一个新 entry
        // 让天数 -1、计时器从 23:59:59 重新起跳；故在每个日界 +1s 处放一个 entry。
        // 进入 24h 内后单个 entry 的 `.timer` 直接计时到 kickoff，自更新无需再发 entry。
        var entries: [MatchEntry] = [entryAt(base, date: now)]
        let totalRemaining = base.kickoff.timeIntervalSince(now)
        if totalRemaining > 24 * 60 * 60 {
            let days0 = Int(totalRemaining) / 86400
            var k = days0
            while k >= 1 && entries.count < 200 {
                let d = base.kickoff.addingTimeInterval(-Double(k) * 86400 + 1)
                if d > now { entries.append(entryAt(base, date: d)) }
                k -= 1
            }
        }
        completion(Timeline(entries: entries, policy: .after(base.kickoff.addingTimeInterval(60))))
    }

    private func entryAt(_ base: MatchEntry, date: Date) -> MatchEntry {
        MatchEntry(
            date: date,
            hasMatch: base.hasMatch,
            home: base.home,
            away: base.away,
            comp: base.comp,
            stage: base.stage,
            venue: base.venue,
            kickoff: base.kickoff,
            customTitle: base.customTitle,
            customTeam: base.customTeam,
            logoPath: base.logoPath
        )
    }

    private func readEntry() -> MatchEntry {
        let d = UserDefaults(suiteName: appGroupId)
        let epoch = d?.double(forKey: "kickoffEpoch") ?? 0
        let hasMatch = epoch > 0
        // 自定义提醒时间 (targetEpoch) 存在时，倒计时倒到该时间，否则倒到开赛
        let targetEpoch = d?.double(forKey: "targetEpoch") ?? 0
        let countdownEpoch = targetEpoch > 0 ? targetEpoch : epoch
        return MatchEntry(
            date: Date(),
            hasMatch: hasMatch,
            home: d?.string(forKey: "home") ?? "—",
            away: d?.string(forKey: "away") ?? "—",
            comp: d?.string(forKey: "comp") ?? "",
            stage: d?.string(forKey: "stage") ?? "",
            venue: d?.string(forKey: "venue") ?? "",
            kickoff: hasMatch ? Date(timeIntervalSince1970: countdownEpoch) : Date(),
            customTitle: d?.string(forKey: "customTitle") ?? "",
            customTeam: d?.string(forKey: "customTeam") ?? "",
            logoPath: d?.string(forKey: "reminderLogo") ?? ""
        )
    }
}

struct widgetsEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: Provider.Entry

    var body: some View {
        if #available(iOS 16.0, *), isAccessory {
            accessoryBody
        } else if !entry.hasMatch {
            emptyView
        } else if family == .systemMedium {
            mediumView
        } else {
            smallView
        }
    }

    private var isAccessory: Bool {
        if #available(iOS 16.0, *) {
            return family == .accessoryCircular
                || family == .accessoryRectangular
                || family == .accessoryInline
        }
        return false
    }

    // ── Lock Screen (accessory) families, iOS 16+ ──
    @available(iOS 16.0, *)
    @ViewBuilder
    private var accessoryBody: some View {
        switch family {
        case .accessoryCircular: accessoryCircular
        case .accessoryInline: accessoryInline
        default: accessoryRectangular
        }
    }

    /// 锁屏内联：紧贴时间的一行，显示对阵。
    @available(iOS 16.0, *)
    private var accessoryInline: some View {
        Label(
            entry.hasMatch ? "\(entry.home) – \(entry.away)" : "UMatch",
            systemImage: "soccerball"
        )
    }

    /// 锁屏圆形：>24h 显示天数，否则实时计时 (单色由系统着色)。
    @available(iOS 16.0, *)
    private var accessoryCircular: some View {
        ZStack {
            AccessoryWidgetBackground()
            if entry.hasMatch && entry.kickoff > entry.date {
                VStack(spacing: 0) {
                    Image(systemName: "soccerball").font(.system(size: 10, weight: .bold))
                    if entry.kickoff.timeIntervalSince(entry.date) > 24 * 60 * 60 {
                        Text("\(Int(entry.kickoff.timeIntervalSince(entry.date)) / 86400)d")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .minimumScaleFactor(0.5)
                    } else {
                        Text(entry.kickoff, style: .timer)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.5)
                    }
                }
                .padding(2)
            } else {
                Image(systemName: "soccerball").font(.system(size: 18, weight: .bold))
            }
        }
    }

    /// 锁屏矩形：赛事 + 对阵 + 倒计时三行。
    @available(iOS 16.0, *)
    private var accessoryRectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            if entry.hasMatch {
                HStack(spacing: 3) {
                    Image(systemName: "soccerball").font(.system(size: 11, weight: .bold))
                    Text(entry.stage.isEmpty ? entry.comp : "\(entry.comp) · \(entry.stage)")
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                }
                .widgetAccentable()
                Text("\(entry.home) vs \(entry.away)")
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(1)
                if entry.kickoff > entry.date {
                    if entry.kickoff.timeIntervalSince(entry.date) > 24 * 60 * 60 {
                        let days = Int(entry.kickoff.timeIntervalSince(entry.date)) / 86400
                        let shifted = entry.kickoff.addingTimeInterval(-Double(days) * 86400)
                        HStack(spacing: 3) {
                            Text("\(days)d").font(.system(size: 13, weight: .bold, design: .rounded)).monospacedDigit()
                            Text(shifted, style: .timer).font(.system(size: 13, weight: .bold, design: .rounded)).monospacedDigit()
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    } else {
                        Text(entry.kickoff, style: .timer)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                } else {
                    Text("Kickoff").font(.system(size: 13, weight: .bold, design: .rounded))
                }
            } else {
                Text("UMatch").font(.system(size: 13, weight: .bold))
                Text("No upcoming match").font(.system(size: 12)).foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// logo：优先用 App Group 同步过来的自定义 logo 图片，否则用内置品牌 logo。
    @ViewBuilder
    private var logoImage: some View {
        if !entry.logoPath.isEmpty, let img = UIImage(contentsOfFile: entry.logoPath) {
            Image(uiImage: img).resizable().scaledToFit().clipShape(Circle())
        } else {
            Image("BrandLogo").resizable().scaledToFit()
        }
    }

    /// 顶部标签文案：自定义球队名优先，否则赛事 · 阶段。
    private var compText: String {
        if !entry.customTeam.isEmpty { return entry.customTeam }
        return entry.stage.isEmpty ? entry.comp : "\(entry.comp) · \(entry.stage)"
    }

    private var compLabel: some View {
        HStack(spacing: 6) {
            logoImage
                .frame(width: 28, height: 28)
            Text(compText)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(umGreen)
                .lineLimit(1)
        }
    }

    private var countdown: some View {
        Group {
            if entry.kickoff > entry.date {
                if entry.kickoff.timeIntervalSince(entry.date) > 24 * 60 * 60 {
                    // 超过 24 小时：天数静态 + HH:MM:SS 实时跳动
                    daysCountdown(entry.kickoff.timeIntervalSince(entry.date))
                } else {
                    Text(entry.kickoff, style: .timer)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            } else {
                Text("Kickoff")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(umGreen)
            }
        }
    }

    // "Nd HH:MM:SS"：days 为整天数 (随 timeline entry 静态)，
    // 计时器锚定到 kickoff-days*24h，实时显示日内剩余 HH:MM:SS。
    private func daysCountdown(_ remaining: TimeInterval) -> some View {
        let days = Int(remaining) / 86400
        let shifted = entry.kickoff.addingTimeInterval(-Double(days) * 86400)
        return HStack(spacing: 4) {
            Text("\(days)d")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.primary)
            Text(shifted, style: .timer)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.primary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            compLabel
            Spacer(minLength: 0)
            if entry.customTitle.isEmpty {
                Text(entry.home)
                    .font(.system(size: 14, weight: .bold))
                    .lineLimit(1)
                Text("vs")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.secondary)
                Text(entry.away)
                    .font(.system(size: 14, weight: .bold))
                    .lineLimit(1)
            } else {
                Text(entry.customTitle)
                    .font(.system(size: 15, weight: .bold))
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
            countdown
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 8) {
            compLabel
            Spacer(minLength: 0)
            if entry.customTitle.isEmpty {
                HStack(spacing: 8) {
                    Text(entry.home)
                        .font(.system(size: 16, weight: .bold))
                        .lineLimit(1)
                    Text("vs")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text(entry.away)
                        .font(.system(size: 16, weight: .bold))
                        .lineLimit(1)
                }
            } else {
                Text(entry.customTitle)
                    .font(.system(size: 17, weight: .bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
            if !entry.venue.isEmpty {
                Text(entry.venue)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            countdown
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyView: some View {
        VStack(spacing: 6) {
            Image("BrandLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
            Text("No upcoming match")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension View {
    /// iOS 17+ requires `containerBackground` to opt into the modern widget look;
    /// older iOS uses a plain padded background.
    @ViewBuilder
    func umWidgetBackground() -> some View {
        if #available(iOS 17.0, *) {
            self.containerBackground(.fill.tertiary, for: .widget)
        } else {
            self.padding().background(Color(.systemBackground))
        }
    }
}

struct widgets: Widget {
    let kind: String = "widgets"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            widgetsEntryView(entry: entry)
                .umWidgetBackground()
        }
        .configurationDisplayName("UMatch")
        .description("Countdown to the next match.")
        .supportedFamilies(Self.families)
    }

    /// 主屏 + (iOS 16) 锁屏小组件家族。
    private static var families: [WidgetFamily] {
        if #available(iOS 16.0, *) {
            return [.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline]
        }
        return [.systemSmall, .systemMedium]
    }
}

@available(iOS 17.0, *)
#Preview(as: .systemSmall) {
    widgets()
} timeline: {
    MatchEntry(date: .now, hasMatch: true, home: "Real Madrid", away: "Barcelona", comp: "UCL", stage: "Final", venue: "Wembley", kickoff: .now.addingTimeInterval(60 * 60 * 50))
    MatchEntry(date: .now, hasMatch: false, home: "", away: "", comp: "", stage: "", venue: "", kickoff: .now)
}
