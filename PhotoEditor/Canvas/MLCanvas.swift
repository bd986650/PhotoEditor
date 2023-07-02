//
//  MLCanvas.swift
//  PhotoEditor
//
//  Created by Данил Белов on 01.07.2023.
//

import Foundation
import PencilKit
import CoreML

enum MLCanvasState {
    case inactive, recognizing, releasing
}

/// Canvas used to recognize single drawings and detect simple shapes
class MLCanvas: PKCanvasView {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        minimumZoomScale = 1
        maximumZoomScale = 1
        backgroundColor = .clear
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    /// Shapes classification model
    let model: ShapesClassification? = try? ShapesClassification(configuration: MLModelConfiguration())
    
    // TODO: Shapes classification may be improved using Google ML Kit
    // https://developers.google.com/ml-kit/vision/digital-ink-recognition/ios
    // ML Kit digital ink recognition supports rectangles, triangles, ellipses and arrows
    // Model identifiers are "zxx-Zsym-x-shapes" or "zxx-Zsym-x-autodraw"
    
    /// Current state determine the process to be executed at canvasViewDrawingDidChange()
    var state: MLCanvasState = .inactive
    
    /// Reference to main canvas
    weak var mainCanvas: Canvas?
    
    /// Disable undo/redo functionality
    override var undoManager: UndoManager? { return nil }
    override var editingInteractionConfiguration: UIEditingInteractionConfiguration {
        return .none
    }
    
    /// Clean up the painting from PKCanvasView
    func release() {
        guard state == .releasing else { return }
        state = .inactive
        self.drawing = PKDrawing()
    }
    
    /// Try to detect predefined shapes with ML
    func recognize() {
        guard state == .recognizing else { return }
                
        let image = getImage()
        
        DispatchQueue.global().async { [weak self] in
            
            guard let cgImage = try? self?.processImage(image) else {
                DispatchQueue.main.async {
                    self?.state = .inactive
                    self?.release()
                }
                return
            }
            
            // #if targetEnvironment(simulator)
            // throw "COREML NOT SUPPORTED IN SIMULATORS ON MAC M1 YET"
            // #endif
            
            // run ML prediction
            guard let model = self?.model, let output = try? model.prediction(input: ShapesClassificationInput(imageWith: cgImage)) else {
                DispatchQueue.main.async {
                    self?.state = .inactive
                    self?.release()
                }
                return
            }
            // print(output.classLabel)
            for item in output.classLabelProbs {
                let value = floor(item.value * 100)
                if (value >= 1) {
                    print("\(item.key) \(floor(item.value * 100))%")
                }
            }
            
            guard let probability = output.classLabelProbs[output.classLabel], probability > 0.7 else {
                // low probability
                DispatchQueue.main.async {
                    self?.state = .inactive
                    self?.release()
                }
                return
            }
            
            let shape = DrawingShape(rawValue: output.classLabel)!
            
            DispatchQueue.main.async {
                self?.drawPrefectShape(shape)
                
                self?.state = .inactive
                self?.drawing = PKDrawing()
            }
        }
    }
        
    /// Draw Ideal shape using user's drawing and bounds
    /// Uses PKStroke to draw perfect shapes with current tool, brush size and color
    func drawPrefectShape(_ shape: DrawingShape) {
        var transformed: PKDrawing?
        
        let bounds = drawing.bounds
        print(bounds)

        let tool = self.tool as? PKInkingTool
        transformed = PKDrawing.init(with: shape, in: bounds, tool: tool)
        
        guard let mainCanvas = mainCanvas else {
            return
        }
        
        if let transformed = transformed {
                                                          
            // Canvas before latest drawing and recognition results
            let previous = mainCanvas.previous ?? PKDrawing()
            
            // Canvas with all the finished drawings
            let current = mainCanvas.drawing
            
            guard let undoManager = mainCanvas.undoManager else { return }
            
            // Canvas with all the drawings except the bad shape and including the perfect shape
            mainCanvas.drawing = previous.appending(transformed)
            
            undoManager.registerUndo(withTarget: mainCanvas, handler: {
                $0.drawing = current
                
                // register redo
                /*$0.undoManager?.registerUndo(withTarget: $0, handler: {
                    $0.drawing = main.appending(transformed)
                    // undo ...
                })*/
            })
            undoManager.setActionName("Undo shape")
         
            setNeedsDisplay()
            setNeedsFocusUpdate()
        }
    }
}

/// Image preprocessing
extension MLCanvas {
    /// Get current PKDrawing as UIImage
    func getImage() -> UIImage {
        let bounds = self.drawing.bounds
        // print(bounds)
                                                
        // calculate min square to get full shape with preserving aspect ratio
        var rect: CGRect
        let difference = (bounds.width - bounds.height) / 2
        if (difference >= 0) {
            let origin = CGPoint(x: bounds.origin.x, y: bounds.origin.y - difference)
            let size = CGSize(width: bounds.width, height: bounds.width)
            rect = CGRect(origin: origin, size: size)
        } else {
            let origin = CGPoint(x: bounds.origin.x + difference, y: bounds.origin.y)
            let size = CGSize(width: bounds.height, height: bounds.height)
            rect = CGRect(origin: origin, size: size)
        }
        // print(rect)
    
        return self.drawing.image(from: rect, scale: 1.0)
    }
    
    /// Resize image to 224x224 and apply filters (convert to black and white) to prepare for ML processing
    func processImage(_ image: UIImage) throws -> CGImage {
        // resize to 208x208
        let resized = image.resizeImageTo(size: CGSize(width: 208, height: 208))
        guard let resized = resized else {
            throw "Failed to resize image"
        }
        
        // add 8 white pixels a side
        guard let spaced = resized.withPadding(x: 8, y: 8), let ciSpaced = CoreImage.CIImage(image: spaced) else {
            throw "Failed to extend image with white space and construct CIImage"
        }
                
        // grayscale image
        let gray = try ciSpaced.convertToGrayScale()
        
        // black and white
        guard let bwImage = gray.convertToBlackAndWhite() else {
            throw "Failed to convert to black and white image"
        }
        
        // save to gallery
        // UIImageWriteToSavedPhotosAlbum(bwImage, nil, nil, nil)
        
        guard let cgImage = bwImage.cgImage else {
            throw "Failed to construct grayscale image"
        }
        return cgImage
    }
}
