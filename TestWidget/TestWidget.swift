//
//  TestWidget.swift
//  TestWidget
//
//  Created by issuser on 2026/9/17.
//

import AppIntents
import WidgetKit
import SwiftUI
import UIKit

struct Provider: AppIntentTimelineProvider {

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: ConfigurationAppIntent(), images: [])
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        // 小组件图库 / 添加时的快照，走同一套加载逻辑，命中缓存就会很快
        let images = await loadImages(for: configuration, family: context.family)
        return SimpleEntry(date: Date(), configuration: configuration, images: images)
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let images = await loadImages(for: configuration, family: context.family)
        let entry = SimpleEntry(date: Date(), configuration: configuration, images: images)

        // 半小时后自动换一批
        let nextRefresh = Date().addingTimeInterval(30 * 60)
        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }

    /// 真正干活的地方：算出要几张图 -> 并发下载 -> 组装成 Entry 用的模型
    private func loadImages(for configuration: ConfigurationAppIntent, family: WidgetFamily) async -> [WidgetImage] {
        let layout = WidgetLayout(family: family)
        let count = min(max(configuration.imageCount, 1), layout.capacity)
        let nonce = WidgetRefreshToken.current

        let urls = (0..<count).compactMap {
            configuration.source.url(index: $0, pixelSize: layout.requestPixelSize, nonce: nonce)
        }
        guard !urls.isEmpty else { return [] }

        let images = await ImageLoader.shared.images(
            for: urls,
            maxPixelSize: layout.maxPixelSize
        )

        // 失败的格子保留为 nil，界面上显示占位图，网格不会塌掉
        return urls.enumerated().map { index, url in
            WidgetImage(id: index, url: url, image: images[index])
        }
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
    let images: [WidgetImage]
}

struct TestWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: Provider.Entry

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var content: some View {
        if entry.images.isEmpty {
            StatusView(
                symbol: "photo.on.rectangle.angled",
                title: "暂无图片",
                subtitle: "长按小组件可在配置里选择来源"
            )
        } else if entry.images.allSatisfy({ $0.image == nil }) {
            StatusView(
                symbol: "wifi.exclamationmark",
                title: "加载失败",
                subtitle: "网络不可用，点右下角重试"
            )
        } else {
            grid
                .overlay(alignment: .bottomTrailing) { refreshButton }
        }
    }

    // MARK: - 网格

    private var layout: WidgetLayout { WidgetLayout(family: family) }

    private var grid: some View {
        GeometryReader { proxy in
            let columns = max(1, min(layout.columns, entry.images.count))
            let rows = layout.rows(for: entry.images.count)
            let spacing: CGFloat = 4
            let cellWidth = (proxy.size.width - spacing * CGFloat(columns - 1)) / CGFloat(columns)
            let cellHeight = (proxy.size.height - spacing * CGFloat(rows - 1)) / CGFloat(rows)

            VStack(spacing: spacing) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<columns, id: \.self) { column in
                            tile(at: row * columns + column,
                                 size: CGSize(width: cellWidth, height: cellHeight))
                        }
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    @ViewBuilder
    private func tile(at index: Int, size: CGSize) -> some View {
        if index < entry.images.count {
            let item = entry.images[index]

            Group {
                if let image = item.image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    placeholderTile
                }
            }
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
        } else {
            Color.clear
                .frame(width: size.width, height: size.height)
        }
    }

    private var placeholderTile: some View {
        ZStack {
            Rectangle().fill(.quaternary)
            Image(systemName: "photo")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 换一批

    @ViewBuilder
    private var refreshButton: some View {
        if family != .systemSmall {
            Button(intent: RefreshImagesIntent()) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(6)
                    .background(Color.black.opacity(0.45), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(6)
        }
    }
}

private struct StatusView: View {
    let symbol: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.caption)
                .bold()
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(8)
    }
}

struct TestWidget: Widget {
    let kind: String = "TestWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            TestWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("图片墙")
        .description("从网络下载多张图片并显示")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
    }
}

#Preview(as: .systemMedium) {
    TestWidget()
} timeline: {
    SimpleEntry(date: .now, configuration: ConfigurationAppIntent(), images: WidgetImage.previewSamples)
    SimpleEntry(date: .now, configuration: ConfigurationAppIntent(), images: [])
}
