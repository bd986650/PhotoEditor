//
//  CanvasViewController.swift
//  PhotoEditor
//
//  Created by Данил Белов on 01.07.2023.
//

import UIKit
import PencilKit

class CanvasViewController<T: PKCanvasView>: UIViewController, PKToolPickerObserver, PKCanvasViewDelegate, UIGestureRecognizerDelegate, UITextViewDelegate {
    var canvas: T!
    var onChanged: ((PKDrawing) -> Void)?
    var onSelectionChanged: ((UIView?) -> Void)?
    var shouldBecameFirstResponder: Bool = true
    
    /// Attached tool picker
    var toolPicker: PKToolPicker?
    
    /// Currently active subview
    var highlightedSubview: UIView?
    
    var selectionEnabled = true
    
    init(canvas: T!, onChanged: ((PKDrawing) -> Void)?, onSelectionChanged: ((UIView?) -> Void)?, shouldBecameFirstResponder: Bool) {
        super.init(nibName: nil, bundle: nil)
        self.canvas = canvas
        self.onChanged = onChanged
        self.onSelectionChanged = onSelectionChanged
        self.shouldBecameFirstResponder = shouldBecameFirstResponder
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    /// Insert canvas view
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(canvas)
        
        canvas.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            canvas.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            canvas.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            canvas.topAnchor.constraint(equalTo: view.topAnchor),
            canvas.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        canvas.delegate = self
        canvas.drawingPolicy = .anyInput
    }
 
    /// Setup tool picker and became first responder
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if (canvas is Canvas) {
            let toolPicker = PKToolPicker()
            toolPicker.setVisible(true, forFirstResponder: canvas)
            toolPicker.addObserver(canvas)
            toolPicker.selectedTool = PKInkingTool(.pen, color: .white, width: 5) // default tool
            toolPicker.overrideUserInterfaceStyle = .dark
            toolPicker.colorUserInterfaceStyle = .dark // required for correct black and white colors in different system modes
            self.toolPicker = toolPicker
        }
        
        if (shouldBecameFirstResponder) {
            // https://developer.apple.com/forums/thread/661607
            canvas.becomeFirstResponder()
            canvas.resignFirstResponder()
            canvas.becomeFirstResponder()
        }
    }
        
    /// Nofity the subscriber and process the drawing via ML if needed
    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        onChanged?(canvasView.drawing)
        
        if let canvas = canvasView as? MLCanvas {
            switch (canvas.state) {
            case .recognizing:
                canvas.recognize()
                break;
            case .releasing:
                canvas.release()
                break;
            case .inactive:
                break;
            }
        }
    }
    
    /*func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
        print("canvasViewDidBeginUsingTool")
    }
    
    func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
        print("canvasViewDidEndUsingTool")
    }*/
    
    // MARK: UIView subviews gestures
    
    /// Register all the gestures needed for text subview manipulation
    func registerGestures(for view: UIView) {
        view.center = view.center
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.handleTap(_:)))
        tap.numberOfTapsRequired = 1
        tap.delaysTouchesBegan = true
        view.addGestureRecognizer(tap)
        
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(self.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        doubleTap.delaysTouchesBegan = true
        tap.require(toFail: doubleTap)
        view.addGestureRecognizer(doubleTap)
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        view.addGestureRecognizer(longPress)
        
        let gestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        gestureRecognizer.delegate = self
        view.addGestureRecognizer(gestureRecognizer)
        
        // MARK: Used for scaling may be disable - implemented via slider
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinchGesture.delegate = self
        view.addGestureRecognizer(pinchGesture)
        
        let rotate = UIRotationGestureRecognizer.init(target: self, action: #selector(handleRotate(_:)))
        rotate.delegate = self
        view.addGestureRecognizer(rotate)
    }
    
    /// Detect if touched outside of selected text view
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        maybeDeselectSubview(view, touches: touches)
    }
    
    /// Detect if touched on a new text view
    @objc func handleTap(_ tap: UITapGestureRecognizer?) {
        guard selectionEnabled else { return }
        guard let view = tap?.view else { return }
        selectSubview(view)
    }
    
    /// Enter tex editing mode if tapped on text view
    @objc func handleDoubleTap(_ doubleTap: UITapGestureRecognizer?) {
        guard selectionEnabled else { return }
        guard let view = doubleTap?.view as? UILabel else { return }
        selectSubview(view)
        editTextView(view)
    }
        
    /// Show context menu for tapped text view
    @objc func handleLongPress(_ recognizer: UIGestureRecognizer) {
        guard selectionEnabled else { return }
        if let view = recognizer.view, let superview = view.superview {
            selectSubview(view)
            UIMenuController.shared.menuItems = [
                
                // MARK: bringToTop, sendBack implemented via selection - move selected to top, but may be added here as well
                
                UIMenuItem(title: "Edit", action: #selector(editView)),
                UIMenuItem(title: "Duplicate", action: #selector(duplicateView)),
                UIMenuItem(title: "Delete", action: #selector(deleteView))
            ]
            UIMenuController.shared.accessibilityHint = view.accessibilityIdentifier
            UIMenuController.shared.arrowDirection = .default
            UIMenuController.shared.showMenu(from: superview, rect: view.frame)
        }
    }
    
    /// Menu item - show text editing alert view
    @objc func editView(sender: UIMenuController) {
        guard let view = self.view.subviews.first(where: {
            $0.accessibilityIdentifier == sender.accessibilityHint
        }), let label = view as? UILabel else { return }
        editTextView(label)
    }
    
    /// Menu item - duplicate current text view
    @objc func duplicateView(sender: UIMenuController) {
        guard let label = self.view.subviews.first(where: {
            $0.accessibilityIdentifier == sender.accessibilityHint
        }) else { return }
        let copy = label.copyView()
        copy.accessibilityIdentifier = "textview_\(Int.random(in: 0..<65536))"
                
        guard let textLabel = label as? TextLabel else { return }
        
        copy.backgroundColor = textLabel.backgroundColor
        copy.layer.backgroundColor = textLabel.backgroundColor?.cgColor
        copy.layer.cornerRadius = textLabel.styledLayer.cornerRadius
        copy.layer.borderWidth = textLabel.styledLayer.borderWidth
        copy.layer.borderColor = textLabel.styledLayer.borderColor
        copy.layer.masksToBounds = true
        (copy as? TextLabel)?.styledLayer = copy.layer.copied
        
        // TODO: duplication offset (44, 44) maybe out of screen bounds
        UIView.animate(withDuration: 0.5, delay: 0, options: .curveEaseInOut, animations: {
            copy.frame = CGRect(x: copy.frame.minX + 44, y: copy.frame.minY + 44, width: copy.frame.width, height: copy.frame.height)
        }, completion: nil)
                        
        self.registerGestures(for: copy)
        self.view.addSubview(copy)
        
        deselectSubview(label)
        deselectSubview(copy)
        
        self.undoManager?.registerUndo(withTarget: self, handler: { _ in
            copy.removeFromSuperview()
        })
    }

    /// Menu item - delete selected text view
    @objc func deleteView(sender: UIMenuController) {
        guard let label = self.view.subviews.first(where: {
            $0.accessibilityIdentifier == sender.accessibilityHint
        }) else { return }
        label.removeFromSuperview()
        highlightedSubview = nil
        onSelectionChanged?(nil)
        
        self.undoManager?.registerUndo(withTarget: self, handler: { controller in
            controller.view.addSubview(label)
        })
    }
    
    /// Text view moving gesture
    @objc func handlePan(_ pan: UIPanGestureRecognizer) {
        /*if (pan.state == .began || pan.state == .changed) {
            guard let view = pan.view else { return }
            let translation = pan.translation(in: self.view)
            view.center = CGPoint(x: view.center.x + translation.x, y: view.center.y + translation.y)
            pan.setTranslation(CGPoint.zero, in: self.view)
        }*/
        
        // preventing view from moving outside of parent https://stackoverflow.com/a/17234997
        if (pan.state == .began || pan.state == .changed) {
            guard let view = pan.view else { return }
            let superviewSize = self.view.bounds.size
            let thisSize = view.bounds.size
            let translation = pan.translation(in: self.view)
            
            var center = CGPoint(x: view.center.x + translation.x, y: view.center.y + translation.y)
            var resetTranslation = CGPoint(x: translation.x, y: translation.y)
                        
            // improved horizontal check to be relative to screen bounds
            // because self.view in expanded in fill content mode (only horizontally)
            let globalBounds = self.view.convert(self.view.bounds, to: nil)
            let globalCenter = self.view.convert(center, to: nil)
      
            // TODO: CAN BE OPTIMIZED WITHOUT IF
            if (globalBounds.minX > 0) {
                // case when width is less the the screen bounds
                if globalCenter.x - thisSize.width/2 < globalBounds.minX {
                    center.x = thisSize.width/2
                } else if globalCenter.x + thisSize.width/2 > UIScreen.main.bounds.width - globalBounds.minX {
                    center.x = globalBounds.maxX - globalBounds.minX - thisSize.width/2
                } else {
                    // reset the horizontal translation if the view is moving horizontally
                    resetTranslation.x = 0
                }
            } else {
                // normally this algorithm was used
                if globalCenter.x - thisSize.width/2 < 0 {
                    center.x = thisSize.width/2 - globalBounds.minX
                } else if globalCenter.x + thisSize.width/2 > UIScreen.main.bounds.width {
                    center.x = globalBounds.maxX - thisSize.width/2
                } else {
                    // reset the horizontal translation if the view is moving horizontally
                    resetTranslation.x = 0
                }
            }

            if center.y - thisSize.height/2 < 0 {
                center.y = thisSize.height/2
            } else if center.y + thisSize.height/2 > superviewSize.height {
                center.y = superviewSize.height - thisSize.height/2
            } else {
                // reset the vertical translation if the view is moving vertical
                resetTranslation.y = 0
            }
                        
            view.center = center
            pan.setTranslation(CGPoint.zero, in: self.view)
        }
    }

    /// Text view scalling gesture
    @objc func handlePinch(_ pinch: UIPinchGestureRecognizer) {

        // TODO: font of UILabel may be scalled using https://stackoverflow.com/a/54232901
        
        // TODO: logic for disallowing to scale outside of self.view may be taken from handlePan()
        
        guard let view = pinch.view else { return }
        view.transform = view.transform.scaledBy(x: pinch.scale, y: pinch.scale)
        pinch.scale = 1
    }

    /// Text view rotating gesture
    @objc func handleRotate(_ rotate: UIRotationGestureRecognizer) {
        guard let view = rotate.view else { return }
        view.transform = view.transform.rotated(by: rotate.rotation)
        rotate.rotation = 0
    }
       
    /// Allow multiple gestures to be invoked in same time
    func gestureRecognizer(_: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith shouldRecognizeSimultaneouslyWithGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    override var canBecomeFirstResponder: Bool {
        return true
    }
    
    /// Selected passed view - will highlight with the blue border
    func selectSubview(_ view: UIView) {
        guard selectionEnabled else { return }
        
        if let highlighted = highlightedSubview {
            // same view selected
            guard view != highlighted else { return }
            
            // deselect another one
            // highlighted.layer.borderColor = UIColor.black.cgColor
            if let label = highlighted as? TextLabel {
                highlighted.layer.cornerRadius = label.styledLayer.cornerRadius
                highlighted.layer.borderWidth = label.styledLayer.borderWidth
                highlighted.layer.borderColor = label.styledLayer.borderColor
            }
        }
        
        view.layer.borderColor = UIColor.systemBlue.cgColor
        view.layer.borderWidth = 3.0
        
        highlightedSubview = view
        onSelectionChanged?(view)
        self.view.bringSubviewToFront(view)
    }
    
    /// Deselect text view if all the touches are outside its bounds
    func maybeDeselectSubview(_ view: UIView, touches: Set<UITouch>) {
        guard let view = highlightedSubview else { return }
        
        for touch in touches {
            if !view.bounds.contains(touch.location(in: view)) {
                deselectSubview(view)
                return
            }
        }
    }
    
    /// Deselect passed text view - will revert border and style back
    func deselectSubview(_ view: UIView) {
        // print("deselect \(view.accessibilityIdentifier!)")
        // view.layer.borderColor = UIColor.black.cgColor
        if let label = view as? TextLabel {
            view.layer.cornerRadius = label.styledLayer.cornerRadius
            view.layer.borderWidth = label.styledLayer.borderWidth
            view.layer.borderColor = label.styledLayer.borderColor
        }
        highlightedSubview = nil
        onSelectionChanged?(nil)
    }
    
    /// Shortcut to show text eding dialog
    func editTextView(_ view: UILabel) {
        self.showTextAlert(title: "Edit", text: view.text, actionTitle: "Save") { text in
            view.text = text
            let size = view.intrinsicContentSize
            view.bounds.size = CGSize(width: size.width + 32, height: size.height + 24)
        }
    }
    
    // MARK: Alert Text View
    
    /// Present add/edit text view dialog
    func showTextAlert(title: String, text: String?, actionTitle: String, onSubmit: ((String) -> Void)?) {
        let alert = UIAlertController(title: title, message: "\n\n\n\n\n\n\n\n", preferredStyle: .alert)
        alert.view.autoresizesSubviews = true
        alert.overrideUserInterfaceStyle = .dark

        let textView = UITextView(frame: CGRect.zero)
        textView.translatesAutoresizingMaskIntoConstraints = false
        
        textView.textColor = .white
        
        textView.delegate = self
        textView.font = UIFont.systemFont(ofSize: 16)
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        
        // placeholder
        if (text == nil) {
            textView.text = "Aa.."
            textView.textColor = UIColor.lightGray
        } else {
            textView.text = text
        }
        
        // border
        textView.layer.cornerRadius = 5
        
        // constraints
        let leadConstraint = NSLayoutConstraint(item: alert.view!, attribute: .leading, relatedBy: .equal, toItem: textView, attribute: .leading, multiplier: 1.0, constant: -8.0)
        let trailConstraint = NSLayoutConstraint(item: alert.view!, attribute: .trailing, relatedBy: .equal, toItem: textView, attribute: .trailing, multiplier: 1.0, constant: 8.0)
        let topConstraint = NSLayoutConstraint(item: alert.view!, attribute: .top, relatedBy: .equal, toItem: textView, attribute: .top, multiplier: 1.0, constant: -68.0)
        let bottomConstraint = NSLayoutConstraint(item: alert.view!, attribute: .bottom, relatedBy: .equal, toItem: textView, attribute: .bottom, multiplier: 1.0, constant: 52)
        
        alert.view.addSubview(textView)
        NSLayoutConstraint.activate([leadConstraint, trailConstraint, topConstraint, bottomConstraint])
        
        // action buttons
        alert.addAction(UIAlertAction(title: actionTitle, style: .default, handler: { action in
            guard textView.text != "" && !(textView.textColor == UIColor.lightGray && textView.text == "Aa..") else { return }
            onSubmit?(textView.text.trimmingCharacters(in: .whitespacesAndNewlines))
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
        
        present(alert, animated: true)
    }
    
    /// Placeholder related method
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.textColor == UIColor.lightGray {
            textView.text = nil
            textView.textColor = .white
            //textView.textColor = self.traitCollection.userInterfaceStyle == .dark ? .white : .black
        }
    }
    
    /// Placeholder related method
    func textViewDidEndEditing(_ textView: UITextView) {
        if textView.text.isEmpty {
            textView.text = "Aa.."
            textView.textColor = UIColor.lightGray
        }
    }

}
