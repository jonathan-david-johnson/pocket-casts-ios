import CarPlay
import Foundation
import Kingfisher
import PocketCastsDataModel

class CarPlayImageHelper {
    static var imageCache = ImageCache(name: "carplay_cache")
    static var carTraitCollection: UITraitCollection?

    class func imageForPodcast(_ podcast: Podcast, maxSize: CGSize = CPListItem.maximumImageSize) -> UIImage {
        let cacheKey = podcast.uuid

        if let cachedImage = cachedImage(for: cacheKey, maxSize: maxSize) {
            return cachedImage
        }

        let image = ImageManager.sharedManager.cachedImageFor(podcastUuid: podcast.uuid, size: .list) ?? UIImage(named: "noartwork-grid-dark")!

        let adjustedImage = adjustImageIfRequired(image: image)
        cacheImage(adjustedImage, for: cacheKey, maxSize: maxSize)
        return adjustedImage
    }

    /// Radio row artwork: curated bundle asset > prefetched favicon > placeholder.
    /// Stays synchronous — the favicon must already be in `imageCache` (warmed by
    /// `RadioFavoritesService`'s prefetch) or this falls back to the glyph, it
    /// never downloads inline.
    class func imageForStation(stationId: String, logoAsset: String?, faviconUrl: String?, maxSize: CGSize = CPListItem.maximumImageSize) -> UIImage {
        let cacheKey = "station_\(stationId)"

        if let cachedImage = cachedImage(for: cacheKey, maxSize: maxSize) {
            return cachedImage
        }

        // SF Symbol images don't survive `UIImageAsset` registration + resize —
        // `UIImageAsset.image(with:)` hands back a zero-size image for a symbol,
        // which NaNs out `resizeProportionally`, and even without that the
        // processed image doesn't round-trip over the XPC connection to
        // CarPlay's out-of-process render host. Return the symbol as-is, the same
        // way the tab bar icon and M11.6's inline fallback already do.
        let placeholder = UIImage(systemName: "dot.radiowaves.left.and.right")!

        guard case .bundleAsset(let asset) = RadioArtworkSource.resolve(logoAsset: logoAsset, faviconUrl: faviconUrl),
              let bundleImage = UIImage(named: asset) else {
            return placeholder
        }

        let adjustedImage = adjustImageIfRequired(image: bundleImage, maxSize: maxSize)
        cacheImage(adjustedImage, for: cacheKey, maxSize: maxSize)
        return adjustedImage
    }

    /// Downloads `faviconUrl` and stores it under `imageForStation`'s cache key,
    /// so a later synchronous read finds it already warm. No-op for stations with
    /// a curated `logoAsset` (bundle art always wins, per `RadioArtworkSource`), an
    /// unresolvable favicon, or an already-warm cache entry. `completion` always
    /// runs, passing whether a download actually happened — callers use that to
    /// decide whether visible rows need a reload.
    class func prefetchStationImage(stationId: String, logoAsset: String?, faviconUrl: String?, maxSize: CGSize = CPListItem.maximumImageSize, completion: @escaping (Bool) -> Void) {
        let cacheKey = "station_\(stationId)"

        guard cachedImage(for: cacheKey, maxSize: maxSize) == nil,
              case .remote(let url) = RadioArtworkSource.resolve(logoAsset: logoAsset, faviconUrl: faviconUrl) else {
            completion(false)
            return
        }

        KingfisherManager.shared.retrieveImage(with: url) { result in
            guard let image = try? result.get().image else {
                completion(false)
                return
            }
            let adjustedImage = adjustImageIfRequired(image: image, maxSize: maxSize)
            cacheImage(adjustedImage, for: cacheKey, maxSize: maxSize)
            completion(true)
        }
    }

    class func imageForFolder(_ folder: Folder) -> UIImage {
        /// sj_snapshotImage is failing to generate the preview (artworks won't appear)
        /// A workaround is to wrap the view in a UIStackView. This prevents the folder
        /// image from being rendered without the artworks.
        let previewWrapper = UIStackView(frame: Constants.folderPreviewSize)
        let preview = FolderPreviewView(frame: Constants.folderPreviewSize)
        preview.showFolderName = false
        preview.forCarPlay = true
        preview.populateFrom(folder: folder)
        previewWrapper.addArrangedSubview(preview)
        previewWrapper.layoutSubviews()

        let image = previewWrapper.sj_snapshotImage(afterScreenUpdate: true, opaque: true) ?? UIImage(named: "noartwork-grid-dark")!

        return adjustImageIfRequired(image: image)
    }

    class func imageForEpisode(_ episode: BaseEpisode, maxSize: CGSize = CPListItem.maximumImageSize) -> UIImage {
        let cacheKey = episode.cacheKey

        if let cachedImage = cachedImage(for: cacheKey, maxSize: maxSize) {
            return cachedImage
        }

        var image: UIImage?
        if let episode = episode as? Episode {
            image = ImageManager.sharedManager.cachedImageFor(podcastUuid: episode.podcastUuid, size: .list)
        } else if let userEpisode = episode as? UserEpisode {
            image = ImageManager.sharedManager.cachedImageForUserEpisode(episode: userEpisode, size: .list)
        }

        if let image {
            let adjustedImage = adjustImageIfRequired(image: image, maxSize: maxSize)
            cacheImage(adjustedImage, for: cacheKey, maxSize: maxSize)
            return adjustedImage
        }

        return adjustImageIfRequired(image: UIImage(named: "noartwork-list-dark")!, maxSize: maxSize)
    }

    private class func adjustImageIfRequired(image: UIImage, maxSize: CGSize = CPListItem.maximumImageSize) -> UIImage {
        guard let carTraitCollection else { return image }
        return image.carPlayImage(with: carTraitCollection, maxSize: maxSize)
    }

    private static func cachedImage(for key: String, maxSize: CGSize) -> UIImage? {
        let cacheKey = "\(key)_\(maxSize.width)"

        // Check the memory and disk cache
        guard imageCache.isCached(forKey: cacheKey) else { return nil }

        // Try to get from memory first
        if let image = imageCache.retrieveImageInMemoryCache(forKey: cacheKey) {
            return image
        }

        var cachedImage: UIImage? = nil

        imageCache.retrieveImageInDiskCache(forKey: cacheKey, options: [.loadDiskFileSynchronously]) { result in
            switch result {
            case let .success(image):
                cachedImage = image
            default: break
            }
        }

        guard let cachedImage else { return nil }

        // When the image is loaded from disk the scale/etc gets reset, so update it again
        let processedImage = cachedImage.carPlayImage(with: carTraitCollection ?? .current, maxSize: maxSize)

        // Store the processed image in memory again
        imageCache.store(processedImage, forKey: cacheKey, toDisk: false)
        return processedImage
    }

    private static func cacheImage(_ image: UIImage, for key: String, maxSize: CGSize) {
        let cacheKey = "\(key)_\(maxSize.width)"

        imageCache.store(image, forKey: cacheKey)
    }

    private enum Constants {
        static let folderPreviewSize: CGRect = .init(x: 0, y: 0, width: 240, height: 240)
    }
}

// MARK: - CarPlay Resizing

private extension UIImage {
    /// This will process the image for us and return an image that CarPlay expects for its current traits (ie: scaling)
    func carPlayImage(with traits: UITraitCollection, maxSize: CGSize) -> UIImage {
        let imageAsset = UIImageAsset()
        imageAsset.register(self, with: traits)
        let processedImage = imageAsset.image(with: traits)

        // Don't resize if we don't need to
        if processedImage.size == maxSize {
            return processedImage
        }

        // SF Symbol images (e.g. the radio-waves placeholder) can come back from
        // `UIImageAsset.image(with:)` with a zero size — dividing by that in
        // `resizeProportionally` is a 0 * .infinity = NaN, and
        // `UIGraphicsBeginImageContextWithOptions(nan, ...)` is a hard crash. Only
        // raster art (bundle logos, favicons) has a stable non-zero size to scale.
        guard processedImage.size.width > 0, processedImage.size.height > 0 else {
            return processedImage
        }

        // Scale the image to the max size CarPlay expects
        return processedImage.resizeProportionally(to: maxSize, displayScale: traits.displayScale)
    }
}

private extension BaseEpisode {
    var cacheKey: String {
        if let episode = self as? Episode {
            return episode.podcastUuid
        }

        if let userEpisode = self as? UserEpisode {
            return userEpisode.urlForImage().absoluteString
        }

        return uuid
    }
}
