import SwiftUI

struct ProvidersView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var editorTarget: ProviderEditor.Target?
    @State private var confirmClear = false

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.canvas.ignoresSafeArea()
                content
            }
            .navigationTitle("服务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.canvas, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("完成") { dismiss() }
                        .font(.system(size: 15, weight: .medium))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        editorTarget = .new
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .regular))
                    }
                }
            }
            .tint(Palette.ink)
            .sheet(item: $editorTarget) { target in
                ProviderEditor(target: target)
                    .environmentObject(store)
            }
            .confirmationDialog("清空全部对话？", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("清空", role: .destructive) {
                    store.deleteAllConversations()
                }
                Button("取消", role: .cancel) {}
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if store.providers.isEmpty {
            addEmptyState
        } else {
            providerList
        }
    }

    private var addEmptyState: some View {
        Button {
            editorTarget = .new
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .light))
                .foregroundColor(Palette.subink)
                .frame(width: 64, height: 64)
                .overlay(Circle().stroke(Palette.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var providerList: some View {
        List {
            ForEach(store.providers) { provider in
                ProviderRow(provider: provider) {
                    editorTarget = .existing(provider)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: Metric.margin, bottom: 0, trailing: Metric.margin))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button {
                        store.deleteProvider(id: provider.id)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .tint(Palette.ink)

                    Button {
                        editorTarget = .existing(provider)
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .tint(Palette.ink)
                }
            }

            if !store.conversations.isEmpty {
                Button {
                    confirmClear = true
                } label: {
                    Text("清空全部对话")
                        .font(.system(size: 13))
                        .foregroundColor(Palette.subink)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 0, leading: Metric.margin, bottom: 0, trailing: Metric.margin))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 0)
    }
}

struct ProviderRow: View {
    @EnvironmentObject private var store: AppStore
    let provider: Provider
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onEdit) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(provider.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Palette.ink)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(Palette.subink)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                store.setActiveProvider(provider.id)
            } label: {
                Image(systemName: provider.id == store.activeProviderID ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 19, weight: .regular))
                    .foregroundColor(provider.id == store.activeProviderID ? Palette.ink : Palette.hairline)
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("设为默认服务")
        }
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.hairline).frame(height: 0.5)
        }
    }

    private var subtitle: String {
        let host = URL(string: provider.baseURL)?.host ?? provider.baseURL
        let model = provider.model.isEmpty ? "—" : provider.model
        return "\(host) · \(model)"
    }
}
