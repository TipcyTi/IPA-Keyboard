import SwiftUI

struct ConversationListView: View {
    @EnvironmentObject private var store: AppStore
    @Binding var path: NavigationPath
    @State private var showProviders = false

    var body: some View {
        ZStack {
            Palette.canvas.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                if store.sortedConversations.isEmpty {
                    emptyState
                } else {
                    conversationList
                }
            }
        }
        .navigationTitle("对话")
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showProviders) {
            ProvidersView()
                .environmentObject(store)
        }
    }

    private var header: some View {
        HStack(spacing: 0) {
            Text("对话")
                .font(.system(size: 30, weight: .semibold))
                .tracking(-0.6)
                .foregroundColor(Palette.ink)
            Spacer(minLength: 8)
            Button {
                showProviders = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(Palette.ink)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("服务")
            Button {
                startChat()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(Palette.ink)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("新建对话")
        }
        .padding(.leading, Metric.margin)
        .padding(.trailing, Metric.margin - 14)
        .padding(.top, 6)
        .padding(.bottom, 6)
    }

    private var emptyState: some View {
        Button {
            startChat()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .light))
                .foregroundColor(Palette.subink)
                .frame(width: 64, height: 64)
                .overlay(Circle().stroke(Palette.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 40)
    }

    private var conversationList: some View {
        List {
            ForEach(store.sortedConversations) { conversation in
                Button {
                    path.append(conversation.id)
                } label: {
                    ConversationRow(conversation: conversation)
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 0, leading: Metric.margin, bottom: 0, trailing: Metric.margin))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button {
                        store.deleteConversation(conversation.id)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .tint(Palette.ink)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 0)
    }

    private func startChat() {
        if store.providers.isEmpty {
            showProviders = true
            return
        }
        guard let conversation = store.newConversation() else {
            showProviders = true
            return
        }
        path.append(conversation.id)
    }
}

struct ConversationRow: View {
    let conversation: Conversation

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(Palette.ink)
                .lineLimit(1)
            HStack(spacing: 10) {
                Text(preview)
                    .font(.system(size: 13))
                    .foregroundColor(Palette.subink)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(stamp)
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundColor(Palette.subink)
            }
        }
        .padding(.vertical, 15)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.hairline).frame(height: 0.5)
        }
    }

    private var title: String {
        let value = conversation.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "新对话" : value
    }

    private var preview: String {
        guard let last = conversation.messages.last(where: { !$0.isError && !$0.text.isEmpty }) else {
            return " "
        }
        let text = last.text.replacingOccurrences(of: "\n", with: " ")
        return text.isEmpty ? " " : text
    }

    private var stamp: String {
        let date = conversation.updatedAt
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return Self.timeFormatter.string(from: date) }
        if calendar.isDateInYesterday(date) { return "昨天" }
        if calendar.isDate(date, equalTo: Date(), toGranularity: .year) {
            return Self.dayFormatter.string(from: date)
        }
        return Self.yearFormatter.string(from: date)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return formatter
    }()

    private static let yearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy/M/d"
        return formatter
    }()
}
