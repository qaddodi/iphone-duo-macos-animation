import Foundation
import Metal
import MetalKit
import AppKit

public struct Uniforms {
    public var imageSize: SIMD2<Float>
    public var cover: SIMD2<Float>
    public var aspect: Float
    public var turn: Float
    public var blurStrength: Float
    public var refractionStrength: Float
    public var chromaticStrength: Float
    public var edgeGlow: Float
    public var reflectionIntensity: Float
    public var saturation: Float
    public var contrast: Float
    public var darknessStrength: Float
    public var blurCurve: Float
    public var perspectiveStrength: Float
    public var eyeHeightCM: Float
    public var eyeDistanceCM: Float
    public var effectMode: Int32
    public var performanceMode: Int32

    public init(
        imageSize: SIMD2<Float> = .init(1, 1),
        cover: SIMD2<Float> = .init(1, 1),
        aspect: Float = 1.0,
        turn: Float = 0.0,
        blurStrength: Float = 0.55,
        refractionStrength: Float = 0.35,
        chromaticStrength: Float = 0.05,
        edgeGlow: Float = 0.16,
        reflectionIntensity: Float = 0.18,
        saturation: Float = 1.0,
        contrast: Float = 1.0,
        darknessStrength: Float = 1.0,
        blurCurve: Float = 1.25,
        perspectiveStrength: Float = 1.0,
        eyeHeightCM: Float = 45.0,
        eyeDistanceCM: Float = 60.0,
        effectMode: Int32 = 0,
        performanceMode: Int32 = 1
    ) {
        self.imageSize = imageSize
        self.cover = cover
        self.aspect = aspect
        self.turn = turn
        self.blurStrength = blurStrength
        self.refractionStrength = refractionStrength
        self.chromaticStrength = chromaticStrength
        self.edgeGlow = edgeGlow
        self.reflectionIntensity = reflectionIntensity
        self.saturation = saturation
        self.contrast = contrast
        self.darknessStrength = darknessStrength
        self.blurCurve = blurCurve
        self.perspectiveStrength = perspectiveStrength
        self.eyeHeightCM = eyeHeightCM
        self.eyeDistanceCM = eyeDistanceCM
        self.effectMode = effectMode
        self.performanceMode = performanceMode
    }
}

public final class MetalFoldView: MTKView, MTKViewDelegate {
    private var commandQueue: MTLCommandQueue?
    private var pipelineState: MTLRenderPipelineState?
    private var samplerState: MTLSamplerState?
    private var currentTexture: MTLTexture?
    private var imageSize: SIMD2<Float> = .init(1920, 1080)
    private var lastPerformanceMode: PerformanceMode = .balanced

    public var currentTurn: Float = 0.0

    public init(frame: CGRect) {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this Mac")
        }
        super.init(frame: frame, device: device)
        commonInit()
    }

    required init(coder: NSCoder) {
        super.init(coder: coder)
        if self.device == nil {
            self.device = MTLCreateSystemDefaultDevice()
        }
        commonInit()
    }

    private func commonInit() {
        guard let dev = self.device else { return }

        commandQueue = dev.makeCommandQueue()
        delegate = self
        colorPixelFormat = .bgra8Unorm
        clearColor = MTLClearColor(red: 0.003, green: 0.004, blue: 0.005, alpha: 1.0)
        framebufferOnly = false
        enableSetNeedsDisplay = false
        isPaused = false
        preferredFramesPerSecond = 60

        let samplerDesc = MTLSamplerDescriptor()
        samplerDesc.minFilter = .linear
        samplerDesc.magFilter = .linear
        samplerDesc.mipFilter = .linear
        samplerDesc.sAddressMode = .clampToEdge
        samplerDesc.tAddressMode = .clampToEdge
        samplerState = dev.makeSamplerState(descriptor: samplerDesc)

        buildPipeline()
    }

    private func buildPipeline() {
        guard let dev = device else { return }

        var library: MTLLibrary?

        if let libURL = Bundle.main.url(forResource: "default", withExtension: "metallib") {
            library = try? dev.makeLibrary(URL: libURL)
        }

        if library == nil {
            library = dev.makeDefaultLibrary()
        }

        if library == nil,
           let sourceURL = Bundle.main.url(forResource: "FoldShaders", withExtension: "metal"),
           let source = try? String(contentsOf: sourceURL, encoding: .utf8) {
            library = try? dev.makeLibrary(source: source, options: nil)
        }

        guard let lib = library,
              let vertexFunction = lib.makeFunction(name: "foldVertex"),
              let fragmentFunction = lib.makeFunction(name: "foldFragment") else {
            print("[Tiltglass] Failed to load Metal shader library")
            return
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = colorPixelFormat

        do {
            pipelineState = try dev.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            print("[Tiltglass] Metal pipeline error: \(error)")
        }
    }

    public func updateImage(_ cgImage: CGImage) {
        guard let dev = device else { return }

        let width = cgImage.width
        let height = cgImage.height
        imageSize = SIMD2<Float>(Float(width), Float(height))

        let levels = max(1, Int(floor(log2(Double(max(width, height))))) + 1)
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: true
        )
        descriptor.mipmapLevelCount = levels
        descriptor.usage = [.shaderRead, .renderTarget]

        guard let texture = dev.makeTexture(descriptor: descriptor) else { return }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerRow = width * 4
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        if let data = context.data {
            texture.replace(
                region: MTLRegionMake2D(0, 0, width, height),
                mipmapLevel: 0,
                withBytes: data,
                bytesPerRow: bytesPerRow
            )
        }

        if let queue = commandQueue,
           let buffer = queue.makeCommandBuffer(),
           let blit = buffer.makeBlitCommandEncoder() {
            blit.generateMipmaps(for: texture)
            blit.endEncoding()
            buffer.commit()
        }

        currentTexture = texture
    }

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    public func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let pass = view.currentRenderPassDescriptor,
              let pipeline = pipelineState,
              let texture = currentTexture,
              let queue = commandQueue,
              let buffer = queue.makeCommandBuffer(),
              let encoder = buffer.makeRenderCommandEncoder(descriptor: pass) else {
            return
        }

        let settings = AppSettings.shared
        if settings.performanceMode != lastPerformanceMode {
            lastPerformanceMode = settings.performanceMode
            switch settings.performanceMode {
            case .efficiency: preferredFramesPerSecond = 30
            case .balanced: preferredFramesPerSecond = 60
            case .quality: preferredFramesPerSecond = 120
            }
        }

        let size = view.drawableSize
        let aspect = Float(size.width / max(1.0, size.height))
        let imageAspect = imageSize.x / max(1.0, imageSize.y)
        let cover = SIMD2<Float>(
            min(1.0, aspect / imageAspect),
            min(1.0, imageAspect / aspect)
        )

        var uniforms = Uniforms(
            imageSize: imageSize,
            cover: cover,
            aspect: aspect,
            turn: currentTurn,
            blurStrength: Float(settings.blurStrength),
            refractionStrength: Float(settings.refractionStrength),
            chromaticStrength: Float(settings.chromaticStrength),
            edgeGlow: Float(settings.edgeGlow),
            reflectionIntensity: Float(settings.reflectionIntensity),
            saturation: Float(settings.saturation),
            contrast: Float(settings.contrast),
            darknessStrength: Float(settings.darknessStrength),
            blurCurve: Float(settings.blurCurve),
            perspectiveStrength: Float(settings.perspectiveStrength),
            eyeHeightCM: Float(settings.eyeHeightCM),
            eyeDistanceCM: Float(settings.eyeDistanceCM),
            effectMode: Int32(settings.effectMode.rawValue),
            performanceMode: Int32(settings.performanceMode.rawValue)
        )

        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.setFragmentSamplerState(samplerState, index: 0)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        encoder.endEncoding()

        buffer.present(drawable)
        buffer.commit()
    }
}
