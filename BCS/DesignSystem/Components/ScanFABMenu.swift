import SwiftUI

/// Extended FAB that opens into a speed-dial menu (Figma 01b, node 14-463):
/// the FAB morphs from "camera + label" into a 56pt close button, two pill items stack above it
/// with 8pt spacing, and a 28% scrim covers the screen. Tapping the scrim closes the menu.
struct ScanFABMenu: View {
    @Binding var isOpen: Bool
    let label: String
    let photoLabel: String
    let cameraLabel: String
    let onPhoto: () -> Void
    let onCamera: () -> Void
    
    private static let scrim = Color(red: 26 / 255, green: 26 / 255, blue: 36 / 255).opacity(0.28)
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if isOpen {
                Self.scrim
                    .ignoresSafeArea()
                    .onTapGesture { close() }
                    .transition(.opacity)
            }
            
            VStack(alignment: .trailing, spacing: 8) {
                if isOpen {
                    menuItem(icon: .image, label: photoLabel) { close(); onPhoto() }
                    menuItem(icon: .camera, label: cameraLabel) { close(); onCamera() }
                    Color.clear.frame(height: 4)   // 12pt between the last item and the FAB
                }
                fab
            }
            .padding(.trailing, 16)
            .padding(.bottom, 16)
        }
    }
    
    private var fab: some View {
        Button {
            withAnimation(.snappy) { isOpen.toggle() }
        } label: {
            HStack(spacing: 12) {
                IconView(isOpen ? .close : .camera, size: 24, color: isOpen ? M3.onPrimary : M3.onPrimaryContainer)
                if !isOpen {
                    Text(label)
                        .textStyle(.labelLarge)
                        .foregroundStyle(M3.onPrimaryContainer)
                        .transition(.opacity)
                }
            }
            .padding(.leading, isOpen ? 0 : 16)
            .padding(.trailing, isOpen ? 0 : 20)
            .frame(width: isOpen ? 56 : nil, height: 56)
            .background(isOpen ? M3.primary : M3.primaryContainer)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 4)
            .shadow(color: .black.opacity(0.3), radius: 1.5, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
    
    private func menuItem(icon: BCSIcon, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                IconView(icon, size: 24, color: M3.onPrimaryContainer)
                Text(label)
                    .textStyle(.labelLarge)
                    .foregroundStyle(M3.onPrimaryContainer)
            }
            .padding(.leading, 20)
            .padding(.trailing, 24)
            .padding(.vertical, 16)
            .background(M3.primaryContainer)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 4)
            .shadow(color: .black.opacity(0.3), radius: 1.5, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .transition(.scale(scale: 0.8, anchor: .bottomTrailing).combined(with: .opacity))
    }
    
    private func close() {
        withAnimation(.snappy) { isOpen = false }
    }
}

#if DEBUG && canImport(UIKit)
#Preview {
    ZStack(alignment: .bottomTrailing) {
        M3.surfaceContainerLow.ignoresSafeArea()
        ScanFABMenu(isOpen: .constant(true), label: "スキャン", photoLabel: "写真から選ぶ",
                    cameraLabel: "カメラでスキャン", onPhoto: {}, onCamera: {})
    }
}
#endif
