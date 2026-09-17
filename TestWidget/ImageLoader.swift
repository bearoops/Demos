//
//  ImageLoader.swift
//  TestWidget
//
//  网络图片加载器：下载 -> 降采样解码 -> 内存缓存。
//
//  注意：Widget 的视图层是静态渲染，不能使用 AsyncImage，
//  必须在 TimelineProvider 里先把图片下载好，再放进 TimelineEntry。
//  Widget 进程内存上限很小（约 30MB），所以一定要做降采样。
//

import Foundation
import ImageIO
import UIKit

final class ImageLoader: @unchecked Sendable {

    static let shared = ImageLoader()

    /// 单张图最长等待时间（秒）
    static let requestTimeout: TimeInterval = 8

    private let session: URLSession
    private let memoryCache = NSCache<NSString, UIImage>()

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = Self.requestTimeout
        configuration.timeoutIntervalForResource = Self.requestTimeout + 4
        configuration.requestCachePolicy = .useProtocolCachePolicy
        configuration.httpMaximumConnectionsPerHost = 6
        configuration.urlCache = URLCache(
            memoryCapacity: 8 * 1024 * 1024,
            diskCapacity: 64 * 1024 * 1024,
            directory: nil
        )
        session = URLSession(configuration: configuration)
        memoryCache.countLimit = 48
    }

    // MARK: - 对外接口

    /// 并发下载多张图片，按传入顺序返回（失败的为 nil）。
    /// - Parameters:
    ///   - urls: 图片地址
    ///   - maxPixelSize: 解码后的最长边像素，用于降采样
    ///   - deadline: 总耗时上限，超时后取消剩余任务并返回已拿到的部分
    func images(for urls: [URL], maxPixelSize: CGFloat, deadline: TimeInterval = 12) async -> [UIImage?] {
        guard !urls.isEmpty else { return [] }

        return await withTaskGroup(of: (Int, UIImage?).self) { group in
            for (index, url) in urls.enumerated() {
                group.addTask { [self] in
                    (index, await image(for: url, maxPixelSize: maxPixelSize))
                }
            }

            var results = [UIImage?](repeating: nil, count: urls.count)
            var received = 0
            let clock = ContinuousClock()
            let start = clock.now

            for await (index, image) in group {
                results[index] = image
                received += 1
                if received == urls.count { break }
                if start.duration(to: clock.now) > .seconds(deadline) {
                    group.cancelAll()
                    break
                }
            }
            return results
        }
    }

    /// 下载单张图片并降采样解码，命中内存缓存则直接返回。
    func image(for url: URL, maxPixelSize: CGFloat) async -> UIImage? {
        let key = Self.cacheKey(url: url, maxPixelSize: maxPixelSize) as NSString
        if let cached = memoryCache.object(forKey: key) { return cached }

        do {
            let (data, response) = try await session.data(from: url)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                return nil
            }
            guard let image = Self.downsample(data: data, maxPixelSize: maxPixelSize) else {
                return nil
            }
            memoryCache.setObject(image, forKey: key)
            return image
        } catch {
            // 超时 / 断网 / 被取消，统一当作加载失败，由界面展示占位图
            return nil
        }
    }

    // MARK: - 降采样

    /// 用 ImageIO 只解码出需要的大小，避免把整张大图解进内存。
    private static func downsample(data: Data, maxPixelSize: CGFloat) -> UIImage? {
        let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions as CFDictionary) else {
            return nil
        }

        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, Int(maxPixelSize.rounded()))
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    private static func cacheKey(url: URL, maxPixelSize: CGFloat) -> String {
        "\(url.absoluteString)#\(Int(maxPixelSize.rounded()))"
    }
}
