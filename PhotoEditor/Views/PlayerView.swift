//
//  PlayerView.swift
//  PhotoEditor
//
//  Created by Данил Белов on 01.07.2023.
//

import SwiftUI
import AVKit

/// UIKit bridge for looped video player (swiftui native video player supported on ios 14)
struct PlayerView: UIViewRepresentable {
    let asset: AVAsset
    
    @Binding var size: CGSize?
        
    func makeUIView(context: Context) -> UIView {
        PlayerUIView(frame: .zero, asset: asset, size: $size)
    }
    
    func updateUIView(_ uiView: UIView, context: UIViewRepresentableContext<PlayerView>) { }
}

/// Display looped video based on proveded AVAsset
class PlayerUIView: UIView {
    
    private let playerLayer = AVPlayerLayer()
    private var playerLooper: AVPlayerLooper!
    private var queuePlayer: AVQueuePlayer!
    
    private var mediaSize: CGSize?
    
    var size: Binding<CGSize?>
    
    init(frame: CGRect, asset: AVAsset, size: Binding<CGSize?>) {
        self.size = size
        super.init(frame: frame)
        
        // get video size to calculate fitted bounds later
        let tracks = asset.tracks(withMediaType: AVMediaType.video)
        let track = tracks.first
        mediaSize = track?.naturalSize
        // fix the orientation
        if let size = mediaSize, let txf = track?.fixedPreferredTransform {
            if (size.width == txf.tx && size.height == txf.ty) || (txf.tx == 0 && txf.ty == 0) {
                // landscape
            } else {
                // portrait
                mediaSize = CGSize(width: size.height, height: size.width)
            }
        }
        
        let playerItem = AVPlayerItem(asset: asset)
        queuePlayer = AVQueuePlayer(playerItem: playerItem)
        playerLooper = AVPlayerLooper(player: queuePlayer, templateItem: playerItem)
        
        layer.addSublayer(playerLayer)
        playerLayer.player = queuePlayer
        queuePlayer.play()
        
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSublayers(of layer: CALayer) {
        super.layoutSublayers(of: layer)
        // playerLayer.frame = self.bounds
        // return
                
        guard playerLayer.frame == .zero, let mediaSize = mediaSize else {
            playerLayer.frame = self.bounds
            return
        }

        let width: CGFloat
        let height: CGFloat
        if (mediaSize.width > mediaSize.height) {
            // horizontal
            width = layer.frame.size.width
            height = width / mediaSize.width * mediaSize.height
        } else {
            // vertical
            height = layer.frame.size.height
            width = height / mediaSize.height * mediaSize.width
        }
        
        let offsetX = (layer.frame.size.width - width)/2
        let offsetY = (layer.frame.size.height - height)/2
                
        self.frame = CGRect(x: offsetX, y: offsetY, width: width, height: height)
        playerLayer.frame = self.bounds
        
        // update swiftui size (used for overlaying canvas
        self.size.wrappedValue = CGSize(width: width, height: height)
    }
    
    /// Stop player on entering background app mode
    @objc func didEnterBackground() {
        playerLayer.player = nil
    }

    /// Resume player after entering foreground app mode
    @objc func willEnterForeground() {
        playerLayer.player = queuePlayer
        // queuePlayer.play()
    }
}
