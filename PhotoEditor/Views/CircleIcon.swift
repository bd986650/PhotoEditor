//
//  CircleIcon.swift
//  PhotoEditor
//
//  Created by Данил Белов on 01.07.2023.
//

import SwiftUI

/// Circle image used for every icon and button
struct CircleIcon: View {
    
    var systemName: String
    var disabled: Bool = false
    var hidden: Bool = false
    
    var body: some View {
        Image(systemName: systemName)
           .frame(width: 36, height: 36)
           .foregroundColor(hidden ? Color.darkHighlight : disabled ? .gray : .white)
           .background(disabled ? Color(red: 44/255, green: 44/255, blue: 44/255) : Color.darkHighlight)
           .clipShape(Circle())
    }
}
