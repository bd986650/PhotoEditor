//
//  Canvas.swift
//  PhotoEditor
//
//  Created by Данил Белов on 01.07.2023.
//

import Foundation
import PencilKit

class Canvas: PKCanvasView {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        // MARK: A lot of Canvas & Tools customization options available here
        minimumZoomScale = 1
        maximumZoomScale = 1
        backgroundColor = .clear // canvas background color
        overrideUserInterfaceStyle = .dark
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    /// Reference to underlaying canvas
    var mlCanvas: MLCanvas?
    
    /// Drawing to store state before/after recognition
    var previous: PKDrawing?
    
    /// Timer used to detect long press
    var timer: Timer?
    
    /// Point of long press
    var point: CGPoint?
    
     override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
         
         // TODO: MAYBE CLEAR PREVIOUS IN TOUCHES_CANCELLED
         // save current drawing for undo
         previous = drawing

         super.touchesBegan(touches, with: event)
         if let event = event {
             mlCanvas?.drawingGestureRecognizer.touchesBegan(touches, with: event)
         }
     }
     
     override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
         super.touchesMoved(touches, with: event)
         
         if let event = event {
             mlCanvas?.drawingGestureRecognizer.touchesMoved(touches, with: event)
         }
         
         let location = touches.first?.location(in: self)
         defer { point = location }
         
         // skip if touch moved just a bit
         if (location != nil && point != nil) {
             if (abs(location!.x - point!.x) <= 3 && abs(location!.y - point!.y) <= 3) {
                 return
             }
         }

         timer?.invalidate()
         timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in
             self.mlCanvas?.state = .recognizing

             if let event = event {
                 self.mlCanvas?.drawingGestureRecognizer.touchesEnded(touches, with: event)
             }
         }
     }
    
    override func touchesEstimatedPropertiesUpdated(_ touches: Set<UITouch>) {
        super.touchesEstimatedPropertiesUpdated(touches)
        mlCanvas?.drawingGestureRecognizer.touchesEstimatedPropertiesUpdated(touches)
    }
    
     override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
         super.touchesEnded(touches, with: event)
         endTouches(touches, with: event)
     }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        endTouches(touches, with: event)
     }
    
    func endTouches(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let event = event {
            if mlCanvas?.state == .recognizing {
                mlCanvas?.drawingGestureRecognizer.touchesEnded(touches, with: event)
            } else {
                // cancel latest drawing gesture without long press
                mlCanvas?.drawingGestureRecognizer.touchesCancelled(touches, with: event)
            }
        }
        
        // cancel existing timer
        timer?.invalidate()
        
        if mlCanvas?.state == .inactive {
            // clear MLCanvas
            mlCanvas?.state = .releasing
        }
    }
}
