//
//  UIResponder+Extensions.swift
//  PhotoEditor
//
//  Created by Данил Белов on 01.07.2023.
//

import UIKit

extension UIResponder {
    /// Access parent controller
    public var parentViewController: UIViewController? {
        return next as? UIViewController ?? next?.parentViewController
    }
}
