import Foundation
import UIKit
import SwiftSignalKit
import Camera
import MediaEditor
import AVFoundation

public final class EntityVideoRecorder {
    private weak var mediaEditor: MediaEditor?
    private weak var entitiesView: DrawingEntitiesView?
    
    private let maxDuration: Double
    
    private let camera: Camera
    private let previewView: CameraSimplePreviewView
    private let entity: DrawingStickerEntity
    
    private var recordingDisposable = MetaDisposable()
    private let durationPromise = ValuePromise<Double>()
    private let micLevelPromise = Promise<Float>()
    
    public var duration: Signal<Double, NoError> {
        return self.durationPromise.get()
    }
    
    public var micLevel: Signal<Float, NoError> {
        return self.micLevelPromise.get()
    }
    
    public var onAutomaticStop: () -> Void = {}
    
    public init(mediaEditor: MediaEditor, entitiesView: DrawingEntitiesView) {
        self.mediaEditor = mediaEditor
        self.entitiesView = entitiesView
        
        self.maxDuration = min(60.0, mediaEditor.duration ?? 60.0)
        self.previewView = CameraSimplePreviewView(frame: .zero, main: true)
        
        self.entity = DrawingStickerEntity(content: .dualVideoReference(true))
        
        self.camera = Camera(
            configuration: Camera.Configuration(
                preset: .hd1920x1080,
                position: .front,
                isDualEnabled: false,
                audio: true,
                photo: false,
                metadata: false,
                preferredFps: 60.0,
                preferWide: true
            ),
            previewView: self.previewView,
            secondaryPreviewView: nil
        )
        self.camera.startCapture()
        
        let action = { [weak self] in
            self?.previewView.removePlaceholder(delay: 0.15)
            Queue.mainQueue().after(0.1) {
                self?.startRecording()
            }
        }
        if #available(iOS 13.0, *) {
            let _ = (self.previewView.isPreviewing
            |> filter { $0 }
            |> take(1)
            |> deliverOnMainQueue).startStandalone(next: { _ in
                action()
            })
        } else {
            Queue.mainQueue().after(0.35) {
                action()
            }
        }
        
        self.micLevelPromise.set(.single(0.0))
        
        let start = mediaEditor.values.videoTrimRange?.lowerBound ?? 0.0
        mediaEditor.stop()
        mediaEditor.seek(start, andPlay: false)
    }
    
    deinit {
        self.recordingDisposable.dispose()
    }
    
    public func setup(
        referenceDrawingSize: CGSize,
        scale: CGFloat,
        position: CGPoint
    ) {
        self.entity.referenceDrawingSize = referenceDrawingSize
        self.entity.scale = scale
        self.entity.position = position
        self.entitiesView?.add(self.entity)
        
        if let entityView = self.entitiesView?.getView(for: self.entity.uuid) as? DrawingStickerEntityView {
            let maxDuration = self.maxDuration
            entityView.setupCameraPreviewView(
                self.previewView,
                progress: self.durationPromise.get() |> map {
                    Float(max(0.0, min(1.0, $0 / maxDuration)))
                }
            )
            self.previewView.resetPlaceholder(front: true)
            entityView.animateInsertion()
        }
    }

    var start: Double = 0.0
    private func startRecording() {
        guard let mediaEditor = self.mediaEditor else {
            self.onAutomaticStop()
            return
        }
        mediaEditor.maybeMuteVideo()
        mediaEditor.play()
        
        self.start = CACurrentMediaTime()
        self.recordingDisposable.set((self.camera.startRecording()
        |> deliverOnMainQueue).startStrict(next: { [weak self] duration in
            guard let self else {
                return
            }
            self.durationPromise.set(duration)
            if duration >= self.maxDuration {
                let onAutomaticStop = self.onAutomaticStop
                self.stopRecording(save: true, completion: {
                    onAutomaticStop()
                })
            }
        }))
    }
    
    public func stopRecording(save: Bool, completion: @escaping () -> Void = {}) {
        var save = save
        var remove = false
        let duration = CACurrentMediaTime() - self.start
        if duration < 0.2 {
            save = false
            remove = true
        }
        self.recordingDisposable.set((self.camera.stopRecording()
        |> deliverOnMainQueue).startStrict(next: { [weak self] result in
            guard let self, let mediaEditor = self.mediaEditor, let entitiesView = self.entitiesView, case let .finished(mainResult, _, _, _, _) = result else {
                return
            }
            if save {
                let duration = AVURLAsset(url: URL(fileURLWithPath: mainResult.path)).duration
                
                let start = mediaEditor.values.videoTrimRange?.lowerBound ?? 0.0
                mediaEditor.setAdditionalVideoOffset(-start, apply: false)
                mediaEditor.setAdditionalVideoTrimRange(0 ..< duration.seconds, apply: true)
                mediaEditor.setAdditionalVideo(mainResult.path, positionChanges: [])
                
                mediaEditor.stop()
                Queue.mainQueue().justDispatch {
                    mediaEditor.seek(start, andPlay: true)
                }
                
                if let entityView = entitiesView.getView(for: self.entity.uuid) as? DrawingStickerEntityView {
                    entityView.invalidateCameraPreviewView()
                    
                    let entity = self.entity
                    let update = { [weak mediaEditor, weak entity] in
                        if let mediaEditor, let entity {
                            mediaEditor.setAdditionalVideoPosition(entity.position, scale: entity.scale, rotation: entity.rotation)
                        }
                    }
                    entityView.updated = {
                        update()
                    }
                    update()
                }
            } else {
                self.entitiesView?.remove(uuid: self.entity.uuid, animated: true)
                if remove {
                    mediaEditor.setAdditionalVideo(nil, positionChanges: [])
                }
            }
            self.camera.stopCapture(invalidate: true)
            
            self.mediaEditor?.maybeUnmuteVideo()
            
            completion()
        }))
    }
    
    public func togglePosition() {
        self.camera.togglePosition()
    }
}
