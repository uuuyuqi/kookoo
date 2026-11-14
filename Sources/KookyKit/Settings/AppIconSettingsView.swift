import SwiftUI

struct AppIconSettingsView: View {
    @State private var controller = AppIconController.shared
    @State private var pending: AppIconChoice?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("App Icon").font(.headline)
            Text("Choose a Kookoo look. Finder and pinned Dock icons may refresh later than the running app.")
                .font(.caption).foregroundStyle(.secondary)
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
                            Text(choice.name).font(.caption2).lineLimit(1)
                        }
                        .frame(maxWidth: .infinity).padding(6)
                        .background(controller.selectedID == choice.id ? Color.accentColor.opacity(0.15) : .clear,
                                    in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(choice.name) app icon")
                    .accessibilityAddTraits(controller.selectedID == choice.id ? [.isSelected] : [])
                }
            }
            Text("Custom icons modify the installed app and invalidate its code-signature integrity. macOS or company security software may block it. Updates replace the app; your choice is reapplied on launch. Restore Kookoo to use this version’s original icon. No security settings are changed.")
                .font(.caption).foregroundStyle(.secondary)
            if let error = controller.lastError {
                Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled)
            }
        }
        .padding(20)
        .alert("Change installed app icon?", isPresented: Binding(
            get: { pending != nil }, set: { if !$0 { pending = nil } }
        ), presenting: pending) { choice in
            Button("Cancel", role: .cancel) { pending = nil }
            Button("Change Icon") {
                controller.select(choice.id)
                pending = nil
            }
        } message: { _ in
            Text("This changes AppIcon.icns and invalidates the app’s signature integrity. It may affect launching or updates under macOS or your organization’s security policy. Your terminal sessions will not be restarted.")
        }
    }
}
