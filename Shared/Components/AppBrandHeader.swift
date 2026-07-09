import SwiftUI

struct AppBrandHeader: View {
    enum Size {
        case sidebar
        case about

        var iconLength: CGFloat {
            switch self {
            case .sidebar: 32
            case .about: 72
            }
        }

        var wordmarkWidth: CGFloat {
            switch self {
            case .sidebar: 90
            case .about: 156
            }
        }

        var wordmarkHeight: CGFloat {
            switch self {
            case .sidebar: 28
            case .about: 48
            }
        }

        var spacing: CGFloat {
            switch self {
            case .sidebar: 6
            case .about: NativeSpacing.sm
            }
        }

        var wordmarkYOffset: CGFloat {
            switch self {
            case .sidebar: 3
            case .about: 6
            }
        }
    }

    let size: Size
    var alignment: VerticalAlignment = .center

    var body: some View {
        HStack(alignment: alignment, spacing: size.spacing) {
            Image("SidebarBrandIcon")
                .resizable()
                .scaledToFit()
                .frame(width: size.iconLength, height: size.iconLength)

            Image("SidebarWordmark")
                .resizable()
                .scaledToFit()
                .frame(width: size.wordmarkWidth, height: size.wordmarkHeight, alignment: .leading)
                .offset(y: size.wordmarkYOffset)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Ruffnova"))
    }
}

#Preview("App Brand Header") {
    VStack(alignment: .leading, spacing: NativeSpacing.xl) {
        AppBrandHeader(size: .sidebar)
        AppBrandHeader(size: .about)
    }
    .padding()
}
