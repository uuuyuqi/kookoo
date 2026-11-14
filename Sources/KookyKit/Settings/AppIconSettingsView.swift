import SwiftUI

struct AppIconSettingsView: View {
    @State private var controller = AppIconController.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "App Icon", bundle: .kookyResources)).font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 76))], spacing: 12) {
                ForEach(AppIconChoice.all) { choice in
                    Button {
                        controller.select(choice.id)
                    } label: {
                        VStack(spacing: 4) {
                            if let image = controller.image(for: choice.id) {
                                Image(nsImage: image).resizable().frame(width: 48, height: 48)
                            } else {
                                Image(systemName: "app.dashed").frame(width: 48, height: 48)
                            }
                            Text(choice.localizedName).font(.caption2).lineLimit(1)
                        }
                        .frame(maxWidth: .infinity).padding(6)
                        .background(controller.selectedID == choice.id ? Color.accentColor.opacity(0.15) : .clear,
                                    in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(format: String(localized: "%@ app icon", bundle: .kookyResources), choice.localizedName))
                    .accessibilityAddTraits(controller.selectedID == choice.id ? [.isSelected] : [])
                }
            }
            if let error = controller.lastError {
                Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled)
            }
        }
        .padding(20)
    }
}
