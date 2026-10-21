import SwiftUI

struct AskView: View {
    @State private var selectedProduct: Manual?
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @EnvironmentObject private var theme: MD3Theme

    // Mock products
    @State private var products: [Manual] = []

    let quickQuestions = [
        "这个产品怎么安装？",
        "有哪些安全注意事项？",
        "故障代码是什么意思？",
        "如何清洁和保养？"
    ]

    var body: some View {
        VStack(spacing: 0) {
            productChipStrip
            Divider()
            if messages.isEmpty {
                quickQuestionsSection
            } else {
                messageList
            }
            inputBar
        }
        .background(theme.colors.background)
        .navigationTitle("AI 问答")
    }

    private var productChipStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(products) { product in
                    Button {
                        selectedProduct = product
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "book.pages")
                            Text(product.productName)
                                .md3LabelLarge()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(selectedProduct?.id == product.id
                                    ? theme.colors.primaryContainer
                                    : theme.colors.surfaceVariant.opacity(0.4))
                        .foregroundStyle(selectedProduct?.id == product.id
                                        ? theme.colors.onPrimaryContainer
                                        : theme.colors.onSurfaceVariant)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private var quickQuestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("快捷提问")
                .md3TitleSmall()
                .foregroundStyle(theme.colors.onSurfaceVariant)
                .padding(.horizontal, 16)
                .padding(.top, 16)

            ForEach(quickQuestions, id: \.self) { question in
                Button {
                    sendMessage(question)
                } label: {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundStyle(theme.colors.primary)
                        Text(question)
                            .md3BodyMedium()
                            .foregroundStyle(theme.colors.onSurface)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(theme.colors.surfaceVariant.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(messages) { msg in
                        MessageBubble(message: msg)
                    }
                    if isLoading {
                        HStack {
                            ProgressView()
                                .padding(.leading, 16)
                            Spacer()
                        }
                    }
                }
                .padding(16)
            }
            .onChange(of: messages.count) { _ in
                if let last = messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("输入你的问题...", text: $inputText)
                .textFieldStyle(.plain)
                .md3BodyLarge()
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(theme.colors.surfaceVariant.opacity(0.3))
                .clipShape(Capsule())

            Button(action: { sendMessage(inputText) }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(inputText.trim().isEmpty
                                    ? theme.colors.outlineVariant
                                    : theme.colors.primary)
            }
            .disabled(inputText.trim().isEmpty || isLoading)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(theme.colors.surface)
    }

    private func sendMessage(_ text: String) {
        let trimmed = text.trim(); guard !trimmed.isEmpty else { return }
        inputText = ""

        let userMsg = ChatMessage(
            manualID: selectedProduct?.id ?? UUID(),
            role: .user,
            content: trimmed
        )
        messages.append(userMsg)
        isLoading = true

        Task {
            // TODO: call RAGService
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            let ref = ChatReference(pageNumber: 3, snippet: "安装前请确保电源已断开…", confidence: 0.92)
            let reply = ChatMessage(
                manualID: selectedProduct?.id ?? UUID(),
                role: .assistant,
                content: "根据说明书第3页的说明：\n\n" + ref.snippet,
                references: [ref]
            )
            messages.append(reply)
            isLoading = false
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    @EnvironmentObject private var theme: MD3Theme

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == .user { Spacer(minLength: 60) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .md3BodyMedium()
                    .foregroundStyle(message.role == .user
                                    ? theme.colors.onPrimaryContainer
                                    : theme.colors.onSurface)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(message.role == .user
                                ? theme.colors.primaryContainer
                                : theme.colors.surfaceVariant.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                if !message.references.isEmpty {
                    ForEach(message.references) { ref in
                        ReferenceCard(reference: ref)
                    }
                }
            }

            if message.role == .assistant { Spacer(minLength: 60) }
        }
    }
}

#Preview {
    NavigationStack {
        AskView()
            .environmentObject(MD3Theme())
    }
}
