import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

@testable import SocialsCore

private func pngData(width: Int = 4, height: Int = 4) -> Data {
    let bytesPerRow = width * 4
    var pixels = [UInt8](repeating: 200, count: bytesPerRow * height)
    let context = CGContext(
        data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let image = context.makeImage()!

    let output = NSMutableData()
    let destination = CGImageDestinationCreateWithData(
        output, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    _ = CGImageDestinationFinalize(destination)
    return output as Data
}

@Suite("MediaPreparer")
struct MediaPreparerTests {
    @Test("keeps supported bytes and names the file with a real extension")
    func supportedPassthrough() async throws {
        let data = pngData()
        let prepared = try #require(await MediaPreparer.prepare(data: data, contentType: "image/png"))

        #expect(prepared.data == data)
        #expect(prepared.contentType == "image/png")
        #expect(prepared.fileName.hasSuffix(".png"))
        #expect(!prepared.fileName.contains("/"))
    }

    @Test("re-encodes an image type the backend rejects as JPEG")
    func unsupportedImageBecomesJPEG() async throws {
        // Stand-in for the HEIC the camera actually produces: any type outside the
        // allow-list has to come back as JPEG, not be handed over as-is.
        let prepared = try #require(
            await MediaPreparer.prepare(data: pngData(), contentType: "image/heic"))

        #expect(prepared.contentType == "image/jpeg")
        #expect(prepared.fileName.hasSuffix(".jpg"))

        let source = try #require(CGImageSourceCreateWithData(prepared.data as CFData, nil))
        #expect(CGImageSourceGetType(source) as String? == UTType.jpeg.identifier)
    }

    @Test("reports which content types need no conversion")
    func supportedSet() {
        #expect(MediaPreparer.isSupported(contentType: "video/mp4"))
        #expect(MediaPreparer.isSupported(contentType: "IMAGE/JPEG"))
        #expect(!MediaPreparer.isSupported(contentType: "image/heic"))
        #expect(!MediaPreparer.isSupported(contentType: "video/quicktime"))
    }

    @Test("gives up on bytes that are not decodable media")
    func garbageIsRejected() async {
        let prepared = await MediaPreparer.prepare(
            data: Data("not an image".utf8), contentType: "application/octet-stream")

        #expect(prepared == nil)
    }
}
