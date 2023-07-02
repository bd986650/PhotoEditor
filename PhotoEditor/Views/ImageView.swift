//
//  ImageView.swift
//  PhotoEditor
//
//  Created by Данил Белов on 01.07.2023.
//

import SwiftUI

/// Image view to access the self object and calculate fit and fill images sizes
struct ImageView: UIViewRepresentable {
    typealias UIViewType = UIImageView
    
    @Binding var image: UIImage
    var imageView: UIImageView
    
    @Binding var contentMode: UIView.ContentMode
    
    func makeUIView(context: Context) -> UIViewType {
        imageView.image = image
        imageView.backgroundColor = .clear
        imageView.contentMode = contentMode
        imageView.clipsToBounds = true
       
        imageView.setContentHuggingPriority(.defaultLow, for: .vertical)
        imageView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        return imageView
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {
        uiView.image = image
        uiView.contentMode = contentMode
    }
}

