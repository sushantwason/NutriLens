import UIKit

enum ImageProcessor {
    /// Max dimension for API — 1536px gives Claude more detail for food identification
    static let maxDimension: CGFloat = 1536

    /// Prepare an image for Claude Vision API: resize and compress to base64 JPEG
    static func prepareForAPI(_ image: UIImage) -> (base64: String, mediaType: String)? {
        let resized = resize(image, maxDimension: maxDimension)

        // Start at 0.7 quality for better food detail; reduce if needed to stay under 2MB
        var quality: CGFloat = 0.7
        var data = resized.jpegData(compressionQuality: quality)

        while let d = data, d.count > 1_800_000, quality > 0.3 {
            quality -= 0.1
            data = nil  // Release previous buffer before allocating new one
            data = resized.jpegData(compressionQuality: quality)
        }

        guard let finalData = data else { return nil }
        return (finalData.base64EncodedString(), "image/jpeg")
    }

    /// Resize image so the longest edge fits within maxDimension
    static func resize(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
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

    /// Compress image for local storage (smaller than API version)
    static func compressForStorage(_ image: UIImage, maxDimension: CGFloat = 800) -> Data? {
        let resized = resize(image, maxDimension: maxDimension)
        return resized.jpegData(compressionQuality: 0.6)
    }
}
