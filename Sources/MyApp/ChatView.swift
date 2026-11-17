import SwiftUI

struct ChatView: View {
    let conversationID: UUID

    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @State private var showProviders = false
    @FocusState private var inputFocused: Bool

    private static let streamingID = "streaming-bubble"

    private var conversation: Conversation? { store.conversation(id: conversationID) }

    private var title: String {
        guard let title = conversation?.title, !title.isEmpty else { return "对话" }
        return title
    }

    private var isStreaming: Bool {
        guard let streaming = store.streaming else { return false }
        return streaming.conversationID == conversationID
    }

    private var streamingText: String? {
        guard let streaming = store.streaming, streaming.conversationID == conversationID else { return nil }
        return streaming.text
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !store.busy
    }

    private var activeProviderID: UUID? {
        conversation?.providerID ?? store.activeProviderID
    }

    var body: some View {
        ZStack {
            Palette.canvas.ignoresSafeArea()
            transcript
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            composer
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Palette.canvas, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                menu
            }
        }
        .sheet(isPresented: $showProviders) {
            ProvidersView()
                .environmentObject(store)
        }
        .onDisappear {
            store.removeIfEmpty(conversationID)
        }
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 26) {
                    if let messages = conversation?.messages {
                        ForEach(messages) { message in
                            ChatBubble(message: message)
                                .id(message.id)
                        }
                    }
                    if let text = streamingText {
                        StreamingBubble(text: text)
                            .id(Self.streamingID)
                    }
                }
                .padding(.horizontal, Metric.margin)
                .padding(.top, 20)
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: conversation?.messages.count ?? 0) { _ in
                scroll(proxy, animated: true)
            }
            .onChange(of: streamingText ?? "") { _ in
                scroll(proxy, animated: false)
            }
            .onAppear {
                DispatchQueue.main.async {
                    scroll(proxy, animated: false)
                }
            }
        }
    }

    private func scroll(_ proxy: ScrollViewProxy, animated: Bool) {
        DispatchQueue.main.async {
            if streamingText != nil {
                if animated {
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo(Self.streamingID, anchor: .bottom)
                    }
                } else {
                    proxy.scrollTo(Self.streamingID, anchor: .bottom)
                }
            } else if let last = conversation?.messages.last {
                if animated {
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                } else {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    private var composer: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Palette.hairline).frame(height: 0.5)
            HStack(alignment: .bottom, spacing: 10) {
                TextField("", text: $draft, axis: .vertical)
                    .font(.system(size: 16))
                    .foregroundColor(Palette.ink)
                    .tint(Palette.ink)
                    .lineLimit(1...5)
                    .focused($inputFocused)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 19, style: .continuous)
                            .fill(Palette.field)
                    )
                Button(action: primaryAction) {
                    ZStack {
                        Circle().fill(Palette.ink)
                        Image(systemName: isStreaming ? "stop.fill" : "arrow.up")
                            .font(.system(size: isStreaming ? 11 : 14, weight: .bold))
                            .foregroundColor(Palette.onBubble)
                    }
                    .frame(width: 38, height: 38)
                    .opacity(canSend || isStreaming ? 1 : 0.18)
                }
                .buttonStyle(.plain)
                .disabled(!canSend && !isStreaming)
                .accessibilityLabel(isStreaming ? "停止" : "发送")
            }
            .padding(.horizontal, Metric.margin)
            .padding(.top, 10)
            .padding(.bottom, 10)
        }
        .background(Palette.canvas)
    }

    private var menu: some View {
        Menu {
            ForEach(store.providers) { provider in
                Button {
                    store.assign(provider, to: conversationID)
                } label: {
                    if provider.id == activeProviderID {
                        Label(provider.name, systemImage: "checkmark")
                    } else {
                        Text(provider.name)
                    }
                }
            }
            if !store.providers.isEmpty { Divider() }
            Button("服务设置") { showProviders = true }
            Divider()
            Button("删除对话", role: .destructive) {
                store.deleteConversation(conversationID)
                dismiss()
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Palette.ink)
                .frame(width: 30, height: 30)
        }
        .accessibilityLabel("更多")
    }

    private func primaryAction() {
        if isStreaming {
            store.stop()
            return
        }
        let text = draft
        draft = ""
        store.send(text, to: conversationID)
    }
}

struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        Group {
            if message.isError {
                errorBubble
            } else if message.role == .user {
                userBubble
            } else {
                assistantText
            }
        }
    }

    private var errorBubble: some View {
        Text(message.text)
            .font(.system(size: 13))
            .foregroundColor(Palette.subink)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Palette.hairline, lineWidth: 1)
            )
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var userBubble: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 46)
            Text(message.text)
                .font(.system(size: 16))
                .foregroundColor(Palette.onBubble)
                .lineSpacing(3)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: Metric.corner, style: .continuous)
                        .fill(Palette.bubble)
                )
                .textSelection(.enabled)
        }
    }

    private var assistantText: some View {
        Text(message.text)
            .font(.system(size: 16))
            .foregroundColor(Palette.ink)
            .lineSpacing(6)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StreamingBubble: View {
    let text: String
    @State private var dim = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            if text.isEmpty {
                HStack(spacing: 5) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Palette.ink.opacity(dim ? 0.15 : 0.55))
                            .frame(width: 5, height: 5)
                            .animation(
                                .easeInOut(duration: 0.7)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.15),
                                value: dim
                            )
                    }
                }
                .padding(.vertical, 5)
            } else {
                Text(text)
                    .font(.system(size: 16))
                    .foregroundColor(Palette.ink)
                    .lineSpacing(6)
                Rectangle()
                    .fill(Palette.ink.opacity(dim ? 0.15 : 0.5))
                    .frame(width: 7, height: 15)
                    .animation(
                        .easeInOut(duration: 0.7).repeatForever(autoreverses: true),
                        value: dim
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { dim = true }
    }
}
