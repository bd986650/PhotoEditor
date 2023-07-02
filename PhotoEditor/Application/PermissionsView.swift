//
//  PermissionsView.swift
//  PhotoEditor
//
//  Created by Данил Белов on 01.07.2023.
//

import SwiftUI
import Photos

/// Permissions prompting view, the permissions (except the saving one) are NOT required due to using the UIImagePicker for media selction
struct PermissionsView: View {
            
    /// Image picker visibility
    @State var isPickerPresented: Bool = false
    /// Currently selected media item
    @State var selectedItem: MediaItem?
    
    /// Current permissions status
    @State var status: Bool? = {
        switch PHPhotoLibrary.authorizationStatus() {
        case .notDetermined:
            return nil
        case .authorized, .limited:
            return true
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }()
        
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 16) {
                    
                    PlayerView(
                        asset: AVAsset(url: Bundle.main.url(forResource: "duck", withExtension: "mp4")!),
                        size: Binding.constant(CGSize(width: 150, height: 150))
                    )
                    .frame(width: 150, height: 150)
                    
                    Text(self.status == true ? "Edit Your Photos and Videos" : "Access Your Photos and Videos")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.light)
                        .padding(.bottom, 8)
                    
                    Button(action: {
                        if self.status == true {
                            isPickerPresented = true
                        } else if self.status == nil {
                            PHPhotoLibrary.requestAuthorization { status in
                                if status == .authorized || status == .limited {
                                    self.status = true
                                    return
                                }
                                
                                self.status = false
                            }
                        }
                    }, label: {
                        // Permissions button
                        Group {
                            if !isPickerPresented {
                                Text(self.status == true ? "Continue" : "Grant Permissions")
                            } else {
                                ProgressView().foregroundColor(.light)
                            }
                        }
                        .fixedSize()
                        .frame(width: geometry.size.width - 96)
                        .font(.system(size: 17, weight: .bold))
                        .padding()
                        .background(self.status == false ? Color.permissionsBackground : Color.blue)
                        .cornerRadius(8)
                        .foregroundColor(.light)
                    })
                    .disabled(self.status == false)
                }
                
                // Editor overlay
                if selectedItem != nil {
                    EditorView(media: selectedItem!, onClose: {
                        selectedItem = nil
                        isPickerPresented = true
                    })
                }
            }
        }
        .sheet(isPresented: $isPickerPresented) {
            // TODO: small delay on first load on real device
            ImagePicker(didFinishSelection: { media in
                selectedItem = media
                isPickerPresented = false
            })
            .edgesIgnoringSafeArea(.all)
        }
    }
}

struct PermissionsView_Previews: PreviewProvider {
    static var previews: some View {
        PermissionsView()
    }
}

