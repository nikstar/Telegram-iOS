import Foundation
import UIKit
import SwiftSignalKit
import AVFoundation
import CoreImage

final class CameraSession {
    private let singleSession: AVCaptureSession?
    private let multiSession: Any?
    
    init() {
        if #available(iOS 13.0, *) {
            self.multiSession = AVCaptureMultiCamSession()
            self.singleSession = nil
        } else {
            self.singleSession = AVCaptureSession()
            self.multiSession = nil
        }
    }
    
    var session: AVCaptureSession {
        if #available(iOS 13.0, *), let multiSession = self.multiSession as? AVCaptureMultiCamSession {
            return multiSession
        } else if let session = self.singleSession {
            return session
        } else {
            fatalError()
        }
    }
    
    var supportsDualCam: Bool {
        return self.multiSession != nil
    }
}

final class CameraDeviceContext {
    private weak var session: CameraSession?
    private weak var previewView: CameraSimplePreviewView?
    
    private let exclusive: Bool
    
    let device = CameraDevice()
    let input = CameraInput()
    let output: CameraOutput
    
    init(session: CameraSession, exclusive: Bool) {
        self.session = session
        self.exclusive = exclusive
        self.output = CameraOutput(exclusive: exclusive)
    }
    
    func configure(position: Camera.Position, previewView: CameraSimplePreviewView?, audio: Bool, photo: Bool, metadata: Bool) {
        guard let session = self.session else {
            return
        }
        
        self.previewView = previewView
        
        self.device.configure(for: session, position: position)
        self.input.configure(for: session, device: self.device, audio: audio)
        self.output.configure(for: session, device: self.device, input: self.input, previewView: previewView, audio: audio, photo: photo, metadata: metadata)
            
        self.device.configureDeviceFormat(maxDimensions: self.preferredMaxDimensions, maxFramerate: self.preferredMaxFrameRate)
        self.output.configureVideoStabilization()
    }
    
    func switchOutputWith(_ otherContext: CameraDeviceContext) {
//        guard let session = self.session else {
//            return
//        }
//        self.output.reconfigure(for: session, device: self.device, input: self.input, otherPreviewView: otherContext.previewView, otherOutput: otherContext.output)
//        otherContext.output.reconfigure(for: session, device: otherContext.device, input: otherContext.input, otherPreviewView: self.previewView, otherOutput: self.output)
    }
    
    func invalidate() {
        guard let session = self.session else {
            return
        }
        self.output.invalidate(for: session)
        self.input.invalidate(for: session)
    }
    
    private var preferredMaxDimensions: CMVideoDimensions {
        return CMVideoDimensions(width: 1920, height: 1080)
    }
    
    private var preferredMaxFrameRate: Double {
        if !self.exclusive {
            return 30.0
        }
        switch DeviceModel.current {
        case .iPhone14ProMax, .iPhone13ProMax:
            return 60.0
        default:
            return 30.0
        }
    }
}

private final class CameraContext {
    private let queue: Queue
    
    private let session: CameraSession
    
    private var mainDeviceContext: CameraDeviceContext
    private var additionalDeviceContext: CameraDeviceContext?

    private let cameraImageContext = CIContext()
    
    private let initialConfiguration: Camera.Configuration
    private var invalidated = false
    
    private let detectedCodesPipe = ValuePipe<[CameraCode]>()
    fileprivate let modeChangePromise = ValuePromise<Camera.ModeChange>(.none)
    
    var previewNode: CameraPreviewNode? {
        didSet {
            self.previewNode?.prepare()
        }
    }
    
    var previewView: CameraPreviewView? {
        didSet {
            
        }
    }
    
    var simplePreviewView: CameraSimplePreviewView? {
        didSet {
            if let oldValue {
                Queue.mainQueue().async {
                    oldValue.invalidate()
                    self.simplePreviewView?.setSession(self.session.session, autoConnect: true)
                }
            }
        }
    }
    
    var secondaryPreviewView: CameraSimplePreviewView?
    
    private var lastSnapshotTimestamp: Double = CACurrentMediaTime()
    private var lastAdditionalSnapshotTimestamp: Double = CACurrentMediaTime()
    private func savePreviewSnapshot(pixelBuffer: CVPixelBuffer, mirror: Bool, additional: Bool) {
        Queue.concurrentDefaultQueue().async {
            var ciImage = CIImage(cvImageBuffer: pixelBuffer)
            let size = ciImage.extent.size
            if mirror {
                var transform = CGAffineTransformMakeScale(-1.0, 1.0)
                transform = CGAffineTransformTranslate(transform, size.width, 0.0)
                ciImage = ciImage.transformed(by: transform)
            }
            ciImage = ciImage.clampedToExtent().applyingGaussianBlur(sigma: 40.0).cropped(to: CGRect(origin: .zero, size: size))
            if let cgImage = self.cameraImageContext.createCGImage(ciImage, from: ciImage.extent) {
                let uiImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: additional ? .up : .right)
                if additional {
                    CameraSimplePreviewView.saveAdditionalLastStateImage(uiImage)
                } else {
                    CameraSimplePreviewView.saveLastStateImage(uiImage)
                }
            }
        }
    }
        
    private var videoOrientation: AVCaptureVideoOrientation?
    init(queue: Queue, session: CameraSession, configuration: Camera.Configuration, metrics: Camera.Metrics, previewView: CameraSimplePreviewView?, secondaryPreviewView: CameraSimplePreviewView?) {
        self.queue = queue
        self.session = session
        self.initialConfiguration = configuration
        self.simplePreviewView = previewView
        self.secondaryPreviewView = secondaryPreviewView
        
        self.mainDeviceContext = CameraDeviceContext(session: session, exclusive: true)
        self.configure {
            self.mainDeviceContext.configure(position: configuration.position, previewView: self.simplePreviewView, audio: configuration.audio, photo: configuration.photo, metadata: configuration.metadata)
        }
        
        self.mainDeviceContext.output.processSampleBuffer = { [weak self] sampleBuffer, pixelBuffer, connection in
            guard let self else {
                return
            }
            self.previewNode?.enqueue(sampleBuffer)
            
            let timestamp = CACurrentMediaTime()
            if timestamp > self.lastSnapshotTimestamp + 2.5 {
                var mirror = false
                if #available(iOS 13.0, *) {
                    mirror = connection.inputPorts.first?.sourceDevicePosition == .front
                }
                self.savePreviewSnapshot(pixelBuffer: pixelBuffer, mirror: mirror, additional: false)
                self.lastSnapshotTimestamp = timestamp
            }
        }
        
        self.mainDeviceContext.output.processFaceLandmarks = { [weak self] observations in
            guard let self else {
                return
            }
            if let previewView = self.previewView {
                previewView.drawFaceObservations(observations)
            }
        }
        
        self.mainDeviceContext.output.processCodes = { [weak self] codes in
            self?.detectedCodesPipe.putNext(codes)
        }
    }
        
    func startCapture() {
        guard !self.session.session.isRunning else {
            return
        }
        self.session.session.startRunning()
    }
    
    func stopCapture(invalidate: Bool = false) {
        if invalidate {
            self.configure {
                self.mainDeviceContext.invalidate()
            }
        }
        
        self.session.session.stopRunning()
    }
    
    func focus(at point: CGPoint, autoFocus: Bool) {
        let focusMode: AVCaptureDevice.FocusMode
        let exposureMode: AVCaptureDevice.ExposureMode
        if autoFocus {
            focusMode = .continuousAutoFocus
            exposureMode = .continuousAutoExposure
        } else {
            focusMode = .autoFocus
            exposureMode = .autoExpose
        }
        self.mainDeviceContext.device.setFocusPoint(point, focusMode: focusMode, exposureMode: exposureMode, monitorSubjectAreaChange: true)
    }
    
    func setFps(_ fps: Float64) {
        self.mainDeviceContext.device.fps = fps
    }
    
    private var modeChange: Camera.ModeChange = .none {
        didSet {
            if oldValue != self.modeChange {
                self.modeChangePromise.set(self.modeChange)
            }
        }
    }
    
    private var _positionPromise = ValuePromise<Camera.Position>(.unspecified)
    var position: Signal<Camera.Position, NoError> {
        return self._positionPromise.get()
    }
    
    private var tmpPosition: Camera.Position = .back
    func togglePosition() {
        if self.isDualCamEnabled {
//            let targetPosition: Camera.Position
//            if case .back = self.tmpPosition {
//                targetPosition = .front
//            } else {
//                targetPosition = .back
//            }
//            self.tmpPosition = targetPosition
//            self._positionPromise.set(targetPosition)
        } else {
            self.configure {
                self.mainDeviceContext.invalidate()
                
                let targetPosition: Camera.Position
                if case .back = self.mainDeviceContext.device.position {
                    targetPosition = .front
                } else {
                    targetPosition = .back
                }
                self._positionPromise.set(targetPosition)
                self.modeChange = .position
                
                self.mainDeviceContext.configure(position: targetPosition, previewView: self.simplePreviewView, audio: self.initialConfiguration.audio, photo: self.initialConfiguration.photo, metadata: self.initialConfiguration.metadata)
                
                self.queue.after(0.5) {
                    self.modeChange = .none
                }
            }
        }
    }
    
    public func setPosition(_ position: Camera.Position) {
        self.configure {
            self.mainDeviceContext.invalidate()
            
            self._positionPromise.set(position)
            self.modeChange = .position
            
            self.mainDeviceContext.configure(position: position, previewView: self.simplePreviewView, audio: self.initialConfiguration.audio, photo: self.initialConfiguration.photo, metadata: self.initialConfiguration.metadata)
                        
            self.queue.after(0.5) {
                self.modeChange = .none
            }
        }
    }
    
    private var isDualCamEnabled = false
    public func setDualCamEnabled(_ enabled: Bool) {
        guard enabled != self.isDualCamEnabled else {
            return
        }
        self.isDualCamEnabled = enabled
        
        self.modeChange = .dualCamera
        if enabled {
            self.configure {
                self.mainDeviceContext.invalidate()
                self.mainDeviceContext = CameraDeviceContext(session: self.session, exclusive: false)
                self.mainDeviceContext.configure(position: .back, previewView: self.simplePreviewView, audio: self.initialConfiguration.audio, photo: self.initialConfiguration.photo, metadata: self.initialConfiguration.metadata)
            
                self.additionalDeviceContext = CameraDeviceContext(session: self.session, exclusive: false)
                self.additionalDeviceContext?.configure(position: .front, previewView: self.secondaryPreviewView, audio: false, photo: true, metadata: false)
            }
            self.mainDeviceContext.output.processSampleBuffer = { [weak self] sampleBuffer, pixelBuffer, connection in
                guard let self else {
                    return
                }
                self.previewNode?.enqueue(sampleBuffer)
                
                let timestamp = CACurrentMediaTime()
                if timestamp > self.lastSnapshotTimestamp + 2.5 {
                    var mirror = false
                    if #available(iOS 13.0, *) {
                        mirror = connection.inputPorts.first?.sourceDevicePosition == .front
                    }
                    self.savePreviewSnapshot(pixelBuffer: pixelBuffer, mirror: mirror, additional: false)
                    self.lastSnapshotTimestamp = timestamp
                }
            }
            self.additionalDeviceContext?.output.processSampleBuffer = { [weak self] sampleBuffer, pixelBuffer, connection in
                guard let self else {
                    return
                }
                let timestamp = CACurrentMediaTime()
                if timestamp > self.lastAdditionalSnapshotTimestamp + 2.5 {
                    var mirror = false
                    if #available(iOS 13.0, *) {
                        mirror = connection.inputPorts.first?.sourceDevicePosition == .front
                    }
                    self.savePreviewSnapshot(pixelBuffer: pixelBuffer, mirror: mirror, additional: true)
                    self.lastAdditionalSnapshotTimestamp = timestamp
                }
            }
        } else {
            self.configure {
                self.mainDeviceContext.invalidate()
                self.mainDeviceContext = CameraDeviceContext(session: self.session, exclusive: true)
                self.mainDeviceContext.configure(position: .back, previewView: self.simplePreviewView, audio: self.initialConfiguration.audio, photo: self.initialConfiguration.photo, metadata: self.initialConfiguration.metadata)
                
                self.additionalDeviceContext?.invalidate()
                self.additionalDeviceContext = nil
            }
            self.mainDeviceContext.output.processSampleBuffer = { [weak self] sampleBuffer, pixelBuffer, connection in
                guard let self else {
                    return
                }
                self.previewNode?.enqueue(sampleBuffer)
                
                let timestamp = CACurrentMediaTime()
                if timestamp > self.lastSnapshotTimestamp + 2.5 {
                    var mirror = false
                    if #available(iOS 13.0, *) {
                        mirror = connection.inputPorts.first?.sourceDevicePosition == .front
                    }
                    self.savePreviewSnapshot(pixelBuffer: pixelBuffer, mirror: mirror, additional: false)
                    self.lastSnapshotTimestamp = timestamp
                }
            }
        }
        
        self.queue.after(0.5) {
            self.modeChange = .none
        }
    }
    
    private func configure(_ f: () -> Void) {
        self.session.session.beginConfiguration()
        f()
        self.session.session.commitConfiguration()
    }
    
    var hasTorch: Signal<Bool, NoError> {
        return self.mainDeviceContext.device.isTorchAvailable
    }
    
    func setTorchActive(_ active: Bool) {
        self.mainDeviceContext.device.setTorchActive(active)
    }
    
    var isFlashActive: Signal<Bool, NoError> {
        return self.mainDeviceContext.output.isFlashActive
    }
    
    private var _flashMode: Camera.FlashMode = .off {
        didSet {
            self._flashModePromise.set(self._flashMode)
        }
    }
    private var _flashModePromise = ValuePromise<Camera.FlashMode>(.off)
    var flashMode: Signal<Camera.FlashMode, NoError> {
        return self._flashModePromise.get()
    }
    
    func setFlashMode(_ mode: Camera.FlashMode) {
        self._flashMode = mode
    }
    
    func setZoomLevel(_ zoomLevel: CGFloat) {
        self.mainDeviceContext.device.setZoomLevel(zoomLevel)
    }
    
    func setZoomDelta(_ zoomDelta: CGFloat) {
        self.mainDeviceContext.device.setZoomDelta(zoomDelta)
    }
    
    func takePhoto() -> Signal<PhotoCaptureResult, NoError> {
        let orientation = self.videoOrientation ?? .portrait
        if let additionalDeviceContext = self.additionalDeviceContext {
            return combineLatest(
                self.mainDeviceContext.output.takePhoto(orientation: orientation, flashMode: self._flashMode),
                additionalDeviceContext.output.takePhoto(orientation: orientation, flashMode: self._flashMode)
            ) |> map { main, additional in
                if case let .finished(mainImage, _, _) = main, case let .finished(additionalImage, _, _) = additional {
                    return .finished(mainImage, additionalImage, CACurrentMediaTime())
                } else {
                    return .began
                }
            } |> distinctUntilChanged
        } else {
            return self.mainDeviceContext.output.takePhoto(orientation: orientation, flashMode: self._flashMode)
        }
    }
    
    public func startRecording() -> Signal<Double, NoError> {
        if let additionalDeviceContext = self.additionalDeviceContext {
            return combineLatest(
                self.mainDeviceContext.output.startRecording(),
                additionalDeviceContext.output.startRecording()
            ) |> map { value, _ in
                return value
            }
        } else {
            return self.mainDeviceContext.output.startRecording()
        }
    }
    
    public func stopRecording() -> Signal<VideoCaptureResult, NoError> {
        if let additionalDeviceContext = self.additionalDeviceContext {
            return combineLatest(
                self.mainDeviceContext.output.stopRecording(),
                additionalDeviceContext.output.stopRecording()
            ) |> mapToSignal { main, additional in
                if case let .finished(mainResult, _, _) = main, case let .finished(additionalResult, _, _) = additional {
                    return .single(.finished(mainResult, additionalResult, CACurrentMediaTime()))
                } else {
                    return .complete()
                }
            }
        } else {
            return self.mainDeviceContext.output.stopRecording()
        }
    }
    
    var detectedCodes: Signal<[CameraCode], NoError> {
        return self.detectedCodesPipe.signal()
    }
}

public final class Camera {
    public typealias Preset = AVCaptureSession.Preset
    public typealias Position = AVCaptureDevice.Position
    public typealias FocusMode = AVCaptureDevice.FocusMode
    public typealias ExposureMode = AVCaptureDevice.ExposureMode
    public typealias FlashMode = AVCaptureDevice.FlashMode
    
    public struct Configuration {
        let preset: Preset
        let position: Position
        let audio: Bool
        let photo: Bool
        let metadata: Bool
        let preferredFps: Double
        
        public init(preset: Preset, position: Position, audio: Bool, photo: Bool, metadata: Bool, preferredFps: Double) {
            self.preset = preset
            self.position = position
            self.audio = audio
            self.photo = photo
            self.metadata = metadata
            self.preferredFps = preferredFps
        }
    }
    
    private let queue = Queue()
    private var contextRef: Unmanaged<CameraContext>?

    private weak var previewView: CameraPreviewView?
    
    public let metrics: Camera.Metrics
    
    public init(configuration: Camera.Configuration = Configuration(preset: .hd1920x1080, position: .back, audio: true, photo: false, metadata: false, preferredFps: 60.0), previewView: CameraSimplePreviewView? = nil, secondaryPreviewView: CameraSimplePreviewView? = nil) {
        self.metrics = Camera.Metrics(model: DeviceModel.current)
        
        let session = CameraSession()
        session.session.usesApplicationAudioSession = true
        session.session.automaticallyConfiguresApplicationAudioSession = false
        session.session.automaticallyConfiguresCaptureDeviceForWideColor = false
        if let previewView {
            previewView.setSession(session.session, autoConnect: false)
        }
        if let secondaryPreviewView {
            secondaryPreviewView.setSession(session.session, autoConnect: false)
        }
        
        self.queue.async {
            let context = CameraContext(queue: self.queue, session: session, configuration: configuration, metrics: self.metrics, previewView: previewView, secondaryPreviewView: secondaryPreviewView)
            self.contextRef = Unmanaged.passRetained(context)
        }
    }
    
    deinit {
        let contextRef = self.contextRef
        self.queue.async {
            contextRef?.release()
        }
    }
    
    public func startCapture() {
#if targetEnvironment(simulator)
#else
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.startCapture()
            }
        }
#endif
    }
    
    public func stopCapture(invalidate: Bool = false) {
#if targetEnvironment(simulator)
#else
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.stopCapture(invalidate: invalidate)
            }
        }
#endif
    }
    
    public var position: Signal<Camera.Position, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.queue.async {
                if let context = self.contextRef?.takeUnretainedValue() {
                    disposable.set(context.position.start(next: { flashMode in
                        subscriber.putNext(flashMode)
                    }, completed: {
                        subscriber.putCompletion()
                    }))
                }
            }
            return disposable
        }
    }
    
    public func togglePosition() {
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.togglePosition()
            }
        }
    }
    
    public func setPosition(_ position: Camera.Position) {
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.setPosition(position)
            }
        }
    }
    
    public func setDualCamEnabled(_ enabled: Bool) {
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.setDualCamEnabled(enabled)
            }
        }
    }
    
    public func takePhoto() -> Signal<PhotoCaptureResult, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.queue.async {
                if let context = self.contextRef?.takeUnretainedValue() {
                    disposable.set(context.takePhoto().start(next: { value in
                        subscriber.putNext(value)
                    }, completed: {
                        subscriber.putCompletion()
                    }))
                }
            }
            return disposable
        }
    }
    
    public func startRecording() -> Signal<Double, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.queue.async {
                if let context = self.contextRef?.takeUnretainedValue() {
                    disposable.set(context.startRecording().start(next: { value in
                        subscriber.putNext(value)
                    }, completed: {
                        subscriber.putCompletion()
                    }))
                }
            }
            return disposable
        }
    }
    
    public func stopRecording() -> Signal<VideoCaptureResult, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.queue.async {
                if let context = self.contextRef?.takeUnretainedValue() {
                    disposable.set(context.stopRecording().start(next: { value in
                        subscriber.putNext(value)
                    }, completed: {
                        subscriber.putCompletion()
                    }))
                }
            }
            return disposable
        }
    }
    
    public func focus(at point: CGPoint, autoFocus: Bool = true) {
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.focus(at: point, autoFocus: autoFocus)
            }
        }
    }
    
    public func setFps(_ fps: Double) {
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.setFps(fps)
            }
        }
    }
    
    public func setFlashMode(_ flashMode: FlashMode) {
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.setFlashMode(flashMode)
            }
        }
    }
    
    public func setZoomLevel(_ zoomLevel: CGFloat) {
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.setZoomLevel(zoomLevel)
            }
        }
    }
    
    
    public func setZoomDelta(_ zoomDelta: CGFloat) {
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.setZoomDelta(zoomDelta)
            }
        }
    }
    
    public func setTorchActive(_ active: Bool) {
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.setTorchActive(active)
            }
        }
    }
    
    public var hasTorch: Signal<Bool, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.queue.async {
                if let context = self.contextRef?.takeUnretainedValue() {
                    disposable.set(context.hasTorch.start(next: { hasTorch in
                        subscriber.putNext(hasTorch)
                    }, completed: {
                        subscriber.putCompletion()
                    }))
                }
            }
            return disposable
        }
    }
    
    public var isFlashActive: Signal<Bool, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.queue.async {
                if let context = self.contextRef?.takeUnretainedValue() {
                    disposable.set(context.isFlashActive.start(next: { isFlashActive in
                        subscriber.putNext(isFlashActive)
                    }, completed: {
                        subscriber.putCompletion()
                    }))
                }
            }
            return disposable
        }
    }
    
    public var flashMode: Signal<Camera.FlashMode, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.queue.async {
                if let context = self.contextRef?.takeUnretainedValue() {
                    disposable.set(context.flashMode.start(next: { flashMode in
                        subscriber.putNext(flashMode)
                    }, completed: {
                        subscriber.putCompletion()
                    }))
                }
            }
            return disposable
        }
    }

    public func attachPreviewNode(_ node: CameraPreviewNode) {
        let nodeRef: Unmanaged<CameraPreviewNode> = Unmanaged.passRetained(node)
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.previewNode = nodeRef.takeUnretainedValue()
                nodeRef.release()
            } else {
                Queue.mainQueue().async {
                    nodeRef.release()
                }
            }
        }
    }
    
    public func attachPreviewView(_ view: CameraPreviewView) {
        self.previewView = view
        let viewRef: Unmanaged<CameraPreviewView> = Unmanaged.passRetained(view)
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.previewView = viewRef.takeUnretainedValue()
                viewRef.release()
            } else {
                Queue.mainQueue().async {
                    viewRef.release()
                }
            }
        }
    }
    
    public func attachSimplePreviewView(_ view: CameraSimplePreviewView) {
        let viewRef: Unmanaged<CameraSimplePreviewView> = Unmanaged.passRetained(view)
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.simplePreviewView = viewRef.takeUnretainedValue()
                viewRef.release()
            } else {
                Queue.mainQueue().async {
                    viewRef.release()
                }
            }
        }
    }
    
    public var detectedCodes: Signal<[CameraCode], NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.queue.async {
                if let context = self.contextRef?.takeUnretainedValue() {
                    disposable.set(context.detectedCodes.start(next: { codes in
                        subscriber.putNext(codes)
                    }))
                }
            }
            return disposable
        }
    }
    
    public enum ModeChange: Equatable {
        case none
        case position
        case dualCamera
    }
    public var modeChange: Signal<ModeChange, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.queue.async {
                if let context = self.contextRef?.takeUnretainedValue() {
                    disposable.set(context.modeChangePromise.get().start(next: { value in
                        subscriber.putNext(value)
                    }))
                }
            }
            return disposable
        }
    }
}

public final class CameraHolder {
    public let camera: Camera
    public let previewView: CameraPreviewView
    
    public init(camera: Camera, previewView: CameraPreviewView) {
        self.camera = camera
        self.previewView = previewView
    }
}
