//
//  MediaProcessor.swift
//  PhotoEditor
//
//  Created by Данил Белов on 01.07.2023.
//

import Foundation
import AVKit
import Photos
import SwiftUI

enum VideoExportError: Error {
    case failed
    case canceled
}

class MediaProcessor {
    
    /// Overlay sketch layer over video composition
    /// https://stackoverflow.com/a/62652219
    static func addSketchLayer(url: URL, sketchLayer: CALayer, block: @escaping (Result<URL, VideoExportError>) -> Void) {
        let composition = AVMutableComposition()
        let vidAsset = AVURLAsset(url: url)
        
        let videoTrack = vidAsset.tracks(withMediaType: AVMediaType.video)[0]
        let duration = vidAsset.duration
        let vid_timerange = CMTimeRangeMake(start: CMTime.zero, duration: duration)
        
        let videoRect = CGRect(origin: .zero, size: videoTrack.naturalSize)
        let transformedVideoRect = videoRect.applying(videoTrack.preferredTransform)
        let size = transformedVideoRect.size
                
        let compositionvideoTrack: AVMutableCompositionTrack = composition.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: CMPersistentTrackID(kCMPersistentTrackID_Invalid))!
        
        try? compositionvideoTrack.insertTimeRange(vid_timerange, of: videoTrack, at: CMTime.zero)
        compositionvideoTrack.preferredTransform = videoTrack.fixedPreferredTransform

        let videolayer = CALayer()
        videolayer.frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        videolayer.opacity = 1.0
        sketchLayer.contentsScale = 1
        
        let parentlayer = CALayer()
        parentlayer.frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        sketchLayer.frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        parentlayer.addSublayer(videolayer)
        parentlayer.addSublayer(sketchLayer)
        
        let layercomposition = AVMutableVideoComposition()
        layercomposition.frameDuration = CMTimeMake(value: 1, timescale: 30)
        layercomposition.renderScale = 1.0
        layercomposition.renderSize = CGSize(width: size.width, height: size.height)

        layercomposition.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayers: [videolayer], in: parentlayer)
        
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRangeMake(start: CMTime.zero, duration: composition.duration)
        let layerinstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionvideoTrack)
        layerinstruction.setTransform(compositionvideoTrack.preferredTransform, at: CMTime.zero)
        instruction.layerInstructions = [layerinstruction] as [AVVideoCompositionLayerInstruction]
        layercomposition.instructions = [instruction] as [AVVideoCompositionInstructionProtocol]
        
        let compositionAudioTrack:AVMutableCompositionTrack? = composition.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: CMPersistentTrackID(kCMPersistentTrackID_Invalid))
        let audioTracks = vidAsset.tracks(withMediaType: AVMediaType.audio)
        for audioTrack in audioTracks {
            try? compositionAudioTrack?.insertTimeRange(audioTrack.timeRange, of: audioTrack, at: CMTime.zero)
        }
        
        let destinationUrl = URL(fileURLWithPath: NSTemporaryDirectory() + "handdrawn_temp.mp4")
        try? FileManager().removeItem(at: destinationUrl)
        
        let assetExport = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality)!
        // using AVAssetExportPresetHighestQuality will cause video colors to be more red (bug) - https://stackoverflow.com/q/61267613
        assetExport.outputFileType = AVFileType.mp4
        assetExport.outputURL = destinationUrl
        assetExport.videoComposition = layercomposition
                       
        assetExport.exportAsynchronously(completionHandler: {
            switch assetExport.status {
            case AVAssetExportSession.Status.failed:
                block(.failure(.failed))
            case AVAssetExportSession.Status.cancelled:
                block(.failure(.canceled))
            default:
                block(.success(destinationUrl))
            }
        })
    }
        
    /// Overlay markup as layer and save to user's media library
    static func exportVideo(url: URL, layer sketchLayer: CALayer,  onSuccess: @escaping () -> Void, onError: @escaping () -> Void) {
        DispatchQueue.global().async {
            Self.addSketchLayer(url: url, sketchLayer: sketchLayer) { result in
                
                guard let url = try? result.get() else {
                    DispatchQueue.main.async {
                        onError()
                    }
                    return
                }
                
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                }) { saved, error in
                    DispatchQueue.main.async {
                        if saved {
                            onSuccess()
                        } else {
                            onError()
                        }
                    }
                }
            }
        }
    }
    
    /// Draw the markup and save image to user's media library
    static func exportImage(image original: UIImage, markup: UIImage, contentMode: ContentMode, imageView: UIImageView) {
        var original = original
        
        if contentMode == .fill {
            // calculate size of visible image area
            let imageSize = original.size
            let pixelsSize = imageView.aspectFillSize
            
            let h, w, offsetX, offsetY: CGFloat
            if imageSize.width > imageSize.height {
                h = imageSize.height
                w = imageView.bounds.width / pixelsSize.width * imageSize.width
                offsetX = floor((imageSize.width - w) / 2)
                offsetY = 0.0
            } else {
                w = imageSize.width
                h = imageView.bounds.height / pixelsSize.height * imageSize.height
                offsetX = 0.0
                offsetY = floor((imageSize.height - h) / 2)
            }
            let rect = CGRect(x: offsetX, y: offsetY, width: round(w), height: round(h))
            
            if let cgImage = original.cgImage, let cropped = cgImage.cropping(to: rect) {
                original = UIImage(cgImage: cropped)
            }
        }
        
        UIGraphicsBeginImageContextWithOptions(original.size, true, 1.0)
        
        let rect = CGRect(x: 0, y: 0, width: original.size.width, height: original.size.height)
        original.draw(in: rect)
                                        
        markup.draw(in: rect, blendMode: .normal, alpha: 1.0)
        
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }
}
