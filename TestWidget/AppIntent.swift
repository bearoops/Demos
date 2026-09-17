//
//  AppIntent.swift
//  TestWidget
//
//  Created by issuser on 2026/9/17.
//

import AppIntents
import WidgetKit

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "图片墙配置" }
    static var description: IntentDescription { "从网络下载多张图片并显示在小组件上" }

    @Parameter(title: "图片来源", default: ImageSource.picsum)
    var source: ImageSource

    @Parameter(title: "图片数量", description: "想显示几张图（会按小组件尺寸自动裁剪）", default: 6, inclusiveRange: (1, 9))
    var imageCount: Int
}

/// 点小组件右下角的按钮时执行：让时间线立刻重新下载一批新图片。
struct RefreshImagesIntent: AppIntent {
    static var title: LocalizedStringResource { "换一批图片" }
    static var description: IntentDescription { "重新从网络下载一批新图片。" }

    func perform() async throws -> some IntentResult {
        WidgetRefreshToken.bump()
        WidgetCenter.shared.reloadTimelines(ofKind: "TestWidget")
        return .result()
    }
}

/// 用一个自增的 token 拼进图片 URL，点一次「换一批」地址就变一次，从而绕开缓存。
/// Intent 与 TimelineProvider 都跑在小组件进程里，所以直接用 UserDefaults.standard 即可。
enum WidgetRefreshToken {
    private static let key = "TestWidget.refreshToken"

    static var current: Int {
        UserDefaults.standard.integer(forKey: key)
    }

    static func bump() {
        UserDefaults.standard.set(current + 1, forKey: key)
    }
}
