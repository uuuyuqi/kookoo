import SwiftUI

struct AppIconSettingsView: View {
    @State private var controller = AppIconController.shared
    @State private var pending: AppIconChoice?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "App Icon", bundle: .kookyResources)).font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 76))], spacing: 12) {
                ForEach(AppIconChoice.all) { choice in
                    Button {
                        if choice.id == "default" { controller.select(choice.id) }
                        else { pending = choice }
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
        .alert(String(localized: "Change installed app icon?", bundle: .kookyResources), isPresented: Binding(
            get: { pending != nil }, set: { if !$0 { pending = nil } }
        ), presenting: pending) { choice in
            Button(String(localized: "Cancel", bundle: .kookyResources), role: .cancel) { pending = nil }
            Button(String(localized: "Change Icon", bundle: .kookyResources)) {
                controller.select(choice.id)
                pending = nil
            }
        } message: { _ in
            Text(String(localized: "This changes AppIcon.icns and invalidates the app’s signature integrity. It may affect launching or updates under macOS or your organization’s security policy. Your terminal sessions will not be restarted.", bundle: .kookyResources))
        }
    }
}
