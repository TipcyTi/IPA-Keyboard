import Foundation
import Combine

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var providers: [Provider] = []
    @Published private(set) var conversations: [Conversation] = []
    @Published private(set) var activeProviderID: UUID?
    @Published private(set) var streaming: StreamingState?
    @Published private(set) var busy = false

    private var keys: [UUID: String] = [:]
    private var streamTask: Task<Void, Never>?
    private let stateURL: URL

    init() {
        let manager = FileManager.default
        let base = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? manager.temporaryDirectory
        let folder = base.appendingPathComponent("AIChat", isDirectory: true)
        try? manager.createDirectory(at: folder, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableFolder = folder
        try? mutableFolder.setResourceValues(values)
        stateURL = folder.appendingPathComponent("state.json")
        load()
    }

    // MARK: - Providers

    func provider(id: UUID?) -> Provider? {
        guard let id else { return nil }
        return providers.first { $0.id == id }
    }

    func provider(for conversation: Conversation) -> Provider? {
        provider(id: conversation.providerID) ?? provider(id: activeProviderID) ?? providers.first
    }

    func apiKey(for providerID: UUID) -> String? {
        if let cached = keys[providerID] { return cached }
        let value = SecretStore.read(providerID) ?? ""
        keys[providerID] = value
        return value
    }

    func addProvider(name: String, baseURL: String, model: String, apiKey: String) {
        let provider = Provider(name: name, baseURL: baseURL, model: model)
        providers.append(provider)
        SecretStore.save(apiKey, for: provider.id)
        keys[provider.id] = apiKey
        if activeProviderID == nil { activeProviderID = provider.id }
        save()
    }

    func updateProvider(_ provider: Provider, apiKey: String) {
        if let index = providers.firstIndex(where: { $0.id == provider.id }) {
            providers[index] = provider
        }
        SecretStore.save(apiKey, for: provider.id)
        keys[provider.id] = apiKey
        save()
    }

    func deleteProvider(id: UUID) {
        providers.removeAll { $0.id == id }
        SecretStore.delete(id)
        keys[id] = nil
        if activeProviderID == id { activeProviderID = providers.first?.id }
        for index in conversations.indices where conversations[index].providerID == id {
            conversations[index].providerID = nil
        }
        save()
    }

    func setActiveProvider(_ id: UUID) {
        activeProviderID = id
        save()
    }

    // MARK: - Conversations

    var sortedConversations: [Conversation] {
        conversations.sorted { $0.updatedAt > $1.updatedAt }
    }

    func conversation(id: UUID) -> Conversation? {
        conversations.first { $0.id == id }
    }

    @discardableResult
    func newConversation() -> Conversation? {
        guard let provider = provider(id: activeProviderID) ?? providers.first else { return nil }
        let conversation = Conversation(title: "", providerID: provider.id, model: provider.model)
        conversations.insert(conversation, at: 0)
        save()
        return conversation
    }

    func deleteConversation(_ id: UUID) {
        if streaming?.conversationID == id {
            streamTask?.cancel()
            streamTask = nil
            streaming = nil
            busy = false
        }
        conversations.removeAll { $0.id == id }
        save()
    }

    func deleteAllConversations() {
        streamTask?.cancel()
        streamTask = nil
        streaming = nil
        busy = false
        conversations.removeAll()
        save()
    }

    func removeIfEmpty(_ id: UUID) {
        guard let conversation = conversation(id: id), conversation.messages.isEmpty else { return }
        conversations.removeAll { $0.id == id }
        save()
    }

    func assign(_ provider: Provider, to conversationID: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        conversations[index].providerID = provider.id
        conversations[index].model = provider.model
        conversations[index].updatedAt = Date()
        save()
    }

    // MARK: - Chat

    func send(_ rawText: String, to conversationID: UUID) {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, streamTask == nil else { return }
        guard let conversation = conversation(id: conversationID) else { return }
        guard let provider = provider(for: conversation) else {
            appendError("未配置服务", to: conversationID)
            return
        }
        let key = apiKey(for: provider.id) ?? ""
        guard !key.isEmpty else {
            appendError("API Key 为空", to: conversationID)
            return
        }
        let model = conversation.model.isEmpty ? provider.model : conversation.model
        guard !model.isEmpty else {
            appendError("未设置模型", to: conversationID)
            return
        }

        append(ChatMessage(role: .user, text: text), to: conversationID)
        let context = context(for: conversationID)

        busy = true
        streaming = StreamingState(conversationID: conversationID, text: "")
        streamTask = Task { [weak self] in
            await self?.run(
                provider: provider,
                key: key,
                model: model,
                messages: context,
                conversationID: conversationID
            )
        }
    }

    func stop() {
        streamTask?.cancel()
    }

    private func run(
        provider: Provider,
        key: String,
        model: String,
        messages: [APIMessage],
        conversationID: UUID
    ) async {
        var accumulated = ""
        var failure: String?

        do {
            for try await chunk in OpenAIService.stream(
                baseURL: provider.baseURL,
                apiKey: key,
                model: model,
                messages: messages
            ) {
                if Task.isCancelled { break }
                accumulated += chunk
                streaming = StreamingState(conversationID: conversationID, text: accumulated)
            }
        } catch is CancellationError {
        } catch let error as URLError where error.code == .cancelled {
        } catch {
            failure = OpenAIService.describe(error)
        }

        streaming = nil
        streamTask = nil
        busy = false

        if !accumulated.isEmpty {
            append(ChatMessage(role: .assistant, text: accumulated), to: conversationID)
        }
        if let failure {
            append(ChatMessage(role: .assistant, text: failure, isError: true), to: conversationID)
        }
    }

    func appendError(_ text: String, to conversationID: UUID) {
        append(ChatMessage(role: .assistant, text: text, isError: true), to: conversationID)
    }

    private func append(_ message: ChatMessage, to conversationID: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        conversations[index].messages.append(message)
        conversations[index].updatedAt = Date()
        if message.role == .user, conversations[index].title.isEmpty {
            conversations[index].title = Self.title(from: message.text)
        }
        save()
    }

    private func context(for conversationID: UUID) -> [APIMessage] {
        guard let conversation = conversation(id: conversationID) else { return [] }
        var result: [APIMessage] = []
        var budget = 24000
        for message in conversation.messages.reversed() {
            if message.isError { continue }
            let content = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if content.isEmpty { continue }
            if content.count > budget { break }
            budget -= content.count
            result.append(APIMessage(role: message.role.rawValue, content: content))
        }
        return Array(result.reversed())
    }

    private static func title(from text: String) -> String {
        let line = text.split(separator: "\n", omittingEmptySubsequences: true).first.map(String.init) ?? text
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count > 28 ? String(trimmed.prefix(28)) + "…" : trimmed
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: stateURL),
              let state = try? JSONDecoder().decode(PersistedState.self, from: data) else {
            return
        }
        providers = state.providers
        conversations = state.conversations
        activeProviderID = state.activeProviderID ?? state.providers.first?.id
    }

    private func save() {
        let state = PersistedState(
            providers: providers,
            conversations: conversations,
            activeProviderID: activeProviderID
        )
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: stateURL, options: .atomic)
    }
}
