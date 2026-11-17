import SwiftUI

struct ProviderEditor: View {
    enum Target: Identifiable {
        case new
        case existing(Provider)

        var id: String {
            switch self {
            case .new:
                return "new"
            case .existing(let provider):
                return provider.id.uuidString
            }
        }
    }

    enum Field: Hashable {
        case name
        case baseURL
        case apiKey
        case model
    }

    let target: Target

    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var baseURL = ""
    @State private var apiKey = ""
    @State private var model = ""
    @State private var models: [String] = []
    @State private var loadingModels = false
    @FocusState private var focusedField: Field?

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.canvas.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        field("名称") {
                            TextField("", text: $name)
                                .focused($focusedField, equals: .name)
                        }

                        field("Base URL") {
                            TextField("", text: $baseURL)
                                .keyboardType(.URL)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($focusedField, equals: .baseURL)
                        }

                        field("API Key") {
                            SecureField("", text: $apiKey)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($focusedField, equals: .apiKey)
                        }

                        field("模型") {
                            modelField
                        }
                    }
                    .padding(.horizontal, Metric.margin)
                    .padding(.top, 28)
                    .padding(.bottom, 48)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(isNew ? "新建服务" : "编辑服务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                        .font(.system(size: 15, weight: .medium))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") { save() }
                        .font(.system(size: 15, weight: .semibold))
                        .disabled(!canSave)
                }
            }
            .tint(Palette.ink)
        }
        .onAppear(perform: fill)
    }

    private var isNew: Bool {
        if case .new = target { return true }
        return false
    }

    private var canSave: Bool {
        let trimmedBase = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedBase.isEmpty && !trimmedModel.isEmpty
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .tracking(0.8)
                .foregroundColor(Palette.subink)
            content()
                .font(.system(size: 16))
                .foregroundColor(Palette.ink)
                .tint(Palette.ink)
                .padding(.bottom, 9)
            Rectangle().fill(Palette.hairline).frame(height: 0.5)
        }
    }

    private var modelField: some View {
        HStack(spacing: 8) {
            TextField("", text: $model)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .model)

            if loadingModels {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 28, height: 28)
            } else {
                Button {
                    Task { await fetchModels() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Palette.subink)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if !models.isEmpty {
                Menu {
                    ForEach(models, id: \.self) { item in
                        Button(item) { model = item }
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Palette.subink)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
            }
        }
    }

    private func fill() {
        guard case .existing(let provider) = target else { return }
        name = provider.name
        baseURL = provider.baseURL
        model = provider.model
        apiKey = store.apiKey(for: provider.id) ?? ""
    }

    @MainActor
    private func fetchModels() async {
        let base = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !base.isEmpty else { return }
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        loadingModels = true
        do {
            models = try await OpenAIService.models(baseURL: base, apiKey: key)
        } catch {
            models = []
        }
        loadingModels = false
    }

    private func save() {
        let base = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let modelName = model.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        var displayName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if displayName.isEmpty {
            displayName = URL(string: base)?.host ?? base
        }

        switch target {
        case .new:
            store.addProvider(name: displayName, baseURL: base, model: modelName, apiKey: key)
        case .existing(let provider):
            var updated = provider
            updated.name = displayName
            updated.baseURL = base
            updated.model = modelName
            store.updateProvider(updated, apiKey: key)
        }
        dismiss()
    }
}
