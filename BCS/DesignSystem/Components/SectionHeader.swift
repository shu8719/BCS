import SwiftUI

/// Primary-colored section title with an optional trailing count/hint.
struct SectionHeader: View {
    let title: String
    var trailing: String? = nil
    
    init(_ title: String, trailing: String? = nil) {
        self.title = title
        self.trailing = trailing
    }
    
    var body: some View {
        HStack {
            Text(title)
                .textStyle(.titleSmall)
                .foregroundStyle(M3.primary)
            Spacer()
            if let trailing {
                Text(trailing)
                    .textStyle(.bodySmall)
                    .foregroundStyle(M3.onSurfaceVariant)
            }
        }
        .padding(.top, 4)
        .padding(.horizontal, 4)
    }
}
