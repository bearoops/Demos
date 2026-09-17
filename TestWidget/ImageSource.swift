//
//  ImageSource.swift
//  TestWidget
//
//  小组件可选的图片来源，在配置面板里以枚举选择器的形式出现。
//

import AppIntents
import Foundation

enum ImageSource: String, AppEnum {

    /// Lorem Picsum 随机照片
    case picsum
    /// Lorem Picsum 随机照片（黑白）
    case picsumGrayscale
    /// dummyimage 生成的纯色占位图（不依赖图片库，最稳）
    case dummyColor

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "图片来源"

    static var caseDisplayRepresentations: [ImageSource: DisplayRepresentation] = [
        .picsum: "随机照片",
        .picsumGrayscale: "随机照片（黑白）",
        .dummyColor: "纯色占位图"
    ]

    /// 按序号生成下载地址。
    /// - Parameter nonce: 每次点「换一批」都会变，用来绕开缓存拿到新图片。
    func url(index: Int, pixelSize: CGSize, nonce: Int) -> URL? {
        let width = max(1, Int(pixelSize.width.rounded()))
        let height = max(1, Int(pixelSize.height.rounded()))

        switch self {
        case .picsum:
            return URL(string: "https://picsum.photos/seed/w-\(nonce)-\(index)/\(width)/\(height)")
        case .picsumGrayscale:
            return URL(string: "https://picsum.photos/seed/w-\(nonce)-\(index)/\(width)/\(height)?grayscale")
        case .dummyColor:
            let hex = Self.palette[abs(nonce &* 7 &+ index) % Self.palette.count]
            return URL(string: "https://dummyimage.com/\(width)x\(height)/\(hex)/ffffff&text=\(index + 1)")
        }
    }

    private static let palette = [
        "2C3E50", "E74C3C", "16A085", "8E44AD", "D35400",
        "2980B9", "27AE60", "C0392B", "7F8C8D"
    ]
}
