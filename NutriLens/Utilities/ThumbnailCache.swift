import UIKit

/// A shared NSCache-backed thumbnail cache that prevents repeated UIImage(data:) decoding
/// in scrolling views. Images are keyed by their data's hash and target size.
final class ThumbnailCache: @unchecked Sendable {
    static let shared = ThumbnailCache()

    private let cache = NSCache<NSString, UIImage>()

    private init() {
        // Limit to ~30 thumbnails (~50x50 = ~30KB each uncompressed ≈ 1MB total)
        cache.countLimit = 50
    }

    /// Returns a cached thumbnail for the given data, decoding and resizing only on cache miss.
    func thumbnail(for data: Data, size: CGFloat) -> UIImage? {
        let key = cacheKey(dataCount: data.count, dataPrefix: data.prefix(64), size: size)

        if let cached = cache.object(forKey: key) {
            return cached
        }

        guard let image = UIImage(data: data) else { return nil }
        let thumbnail = downsample(image, to: size)
        cache.setObject(thumbnail, forKey: key)
        return thumbnail
    }

    func clearCache() {
        cache.removeAllObjects()
    }

    // MARK: - Private

    private func cacheKey(dataCount: Int, dataPrefix: Data, size: CGFloat) -> NSString {
        // Use data size + first 64 bytes hash + target size as a stable key
        var hasher = Hasher()
        hasher.combine(dataCount)
        hasher.combine(dataPrefix)
        hasher.combine(Int(size))
        return NSString(string: "\(hasher.finalize())")
    }

    private func downsample(_ image: UIImage, to maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longestEdge = max(size.width, size.height)
        guard longestEdge > maxDimension else { return image }

        let scale = maxDimension / longestEdge
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
