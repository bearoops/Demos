//
//  WidgetImage.swift
//  TestWidget
//
//  Entry 里承载的图片模型，以及不同尺寸小组件的布局参数。
//

import Foundation
import UIKit
import WidgetKit

/// 一张已经下载并解码好的图片。image 为 nil 表示这一格下载失败，界面显示占位图。
struct WidgetImage: Identifiable {
    let id: Int
    let url: URL
    let image: UIImage?
}

/// 不同 WidgetFamily 对应的网格布局参数。
struct WidgetLayout {

    /// 每行几列
    let columns: Int
    /// 最多能放几张
    let capacity: Int
    /// 单格的展示尺寸（pt），用于推算下载分辨率
    let cellSize: CGSize

    init(family: WidgetFamily) {
        switch family {
        case .systemSmall:
            self.init(columns: 2, capacity: 4, cellSize: CGSize(width: 76, height: 76))
        case .systemMedium:
            self.init(columns: 3, capacity: 6, cellSize: CGSize(width: 110, height: 66))
        case .systemLarge:
            self.init(columns: 3, capacity: 9, cellSize: CGSize(width: 110, height: 110))
        case .systemExtraLarge:
            self.init(columns: 4, capacity: 12, cellSize: CGSize(width: 128, height: 128))
        case .accessoryRectangular:
            self.init(columns: 1, capacity: 1, cellSize: CGSize(width: 160, height: 64))
        default:
            self.init(columns: 1, capacity: 1, cellSize: CGSize(width: 120, height: 120))
        }
    }

    private init(columns: Int, capacity: Int, cellSize: CGSize) {
        self.columns = columns
        self.capacity = capacity
        self.cellSize = cellSize
    }

    /// 向服务端请求的像素尺寸：按 2x 就够了，再大只是白占内存。
    var requestPixelSize: CGSize {
        CGSize(width: cellSize.width * 2, height: cellSize.height * 2)
    }

    /// 降采样时用的最长边
    var maxPixelSize: CGFloat {
        max(requestPixelSize.width, requestPixelSize.height)
    }

    /// 根据实际图片数量算出需要几行
    func rows(for count: Int) -> Int {
        guard count > 0 else { return 1 }
        return Int(ceil(Double(count) / Double(max(columns, 1))))
    }
}

#if DEBUG
extension WidgetImage {
    /// 供 Xcode 预览使用的假数据，避免预览时真的去联网。
    static var previewSamples: [WidgetImage] {
        let symbols = ["sun.max.fill", "moon.stars.fill", "cloud.rain.fill",
                       "snowflake", "leaf.fill", "flame.fill",
                       "drop.fill", "wind", "sparkles"]
        let colors: [UIColor] = [.systemOrange, .systemIndigo, .systemBlue,
                                 .systemTeal, .systemGreen, .systemRed,
                                 .systemCyan, .systemGray, .systemPurple]

        return symbols.enumerated().compactMap { index, symbol in
            let configuration = UIImage.SymbolConfiguration(pointSize: 44, weight: .medium)
            guard let image = UIImage(systemName: symbol, withConfiguration: configuration)?
                .withTintColor(colors[index % colors.count], renderingMode: .alwaysOriginal)
            else { return nil }

            return WidgetImage(
                id: index,
                url: URL(string: "https://example.com/\(index)")!,
                image: image
            )
        }
    }
}
#endif
