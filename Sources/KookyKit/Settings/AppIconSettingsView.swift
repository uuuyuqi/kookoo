import SwiftUI

struct AppIconSettingsView: View {
    @State private var controller = AppIconController.shared
    @State private var pagination = AppIconPagination(
        choiceCount: AppIconChoice.all.count,
        selectedIndex: AppIconChoice.all.firstIndex { $0.id == AppIconController.shared.selectedID }
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(localized: "App Icon", bundle: .kookyResources)).font(.headline)
                Spacer(minLength: 8)
                if pagination.pageCount > 1 { pageControls }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 8) {
                ForEach(AppIconChoice.all[pagination.visibleRange]) { choice in
                    Button {
                        controller.select(choice.id)
                    } label: {
                        VStack(spacing: 4) {
                            if let image = controller.image(for: choice.id) {
                                Image(nsImage: image).resizable().frame(width: 48, height: 48)
                            } else {
                                Image(systemName: "app.dashed").frame(width: 48, height: 48)
                            }
                            Text(choice.localizedName)
                                .font(.caption2)
                                .multilineTextAlignment(.center)
                                .lineLimit(2, reservesSpace: true)
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

    private var pageControls: some View {
        HStack(spacing: 8) {
            Button {
                pagination.goBack()
            } label: {
                Image(systemName: "chevron.backward").frame(width: 14)
            }
            .disabled(!pagination.canGoBack)
            .accessibilityLabel(String(localized: "Previous icon page", bundle: .kookyResources))
            .help(String(localized: "Previous icon page", bundle: .kookyResources))

            Text(verbatim: "\(pagination.pageNumber) / \(pagination.pageCount)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 38)
                .accessibilityLabel(String(
                    format: String(localized: "Icon page %lld of %lld", bundle: .kookyResources),
                    pagination.pageNumber, pagination.pageCount
                ))

            Button {
                pagination.goForward()
            } label: {
                Image(systemName: "chevron.forward").frame(width: 14)
            }
            .disabled(!pagination.canGoForward)
            .accessibilityLabel(String(localized: "Next icon page", bundle: .kookyResources))
            .help(String(localized: "Next icon page", bundle: .kookyResources))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}
