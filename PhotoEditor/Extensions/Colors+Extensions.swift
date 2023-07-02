//
//  Colors+Extensions.swift
//  PhotoEditor
//
//  Created by Данил Белов on 01.07.2023.
//

import SwiftUI

extension Color {
    /// Main background color
    static let dark = Color(red: 35/255, green: 34/255, blue: 35/255)
    
    /// Main foreground color
    static let light = Color(red: 244/255, green: 244/255, blue: 244/255)
    
    /// Color used for views background which is differ from main background
    static let darkHighlight = Color(red: 44/255, green: 44/255, blue: 44/255)
    
    static let permissionsBackground = Color(red: 29/255, green: 28/255, blue: 30/255)
}

extension UIColor {
    /// Main background color
    static let dark = UIColor(red: 35/255, green: 34/255, blue: 35/255, alpha: 1.0)
    
    /// Main foreground color
    static let light = UIColor(red: 244/255, green: 244/255, blue: 244/255, alpha: 1.0)
}

