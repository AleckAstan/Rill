import SwiftUI

private extension RillAgentPhase {
    var tint: Color {
        switch self {
        case .working: Color(red: 0.88, green: 0.60, blue: 0.39)
        case .approval: Color(red: 1, green: 0.73, blue: 0.35)
        case .waiting, .completed: Color(red: 0.43, green: 0.85, blue: 0.44)
        case .unknown: .gray
        }
    }

    var caption: String {
        switch self {
        case .working: "Working"
        case .approval: "Waiting for approval"
        case .waiting: "Waiting for input"
        case .completed: "Completed"
        case .unknown: "Unavailable"
        }
    }
}

struct AgentDashboardView: View {
    let content: RillAgentDashboard
    let packageDirectory: URL
    let action: (String) -> Void
    @State private var usageDetail: String?

    private var selectedSession: RillAgentSession? {
        content.sessions.first { $0.id == content.selectedSessionID }
    }

    var body: some View {
        VStack(spacing: 0) {
            if let session = selectedSession {
                conversation(session)
            } else {
                sessionList
            }
            if let status = content.status {
                Text(status).font(.system(size: 10)).foregroundStyle(.white.opacity(0.45))
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 12)
            }
            footer
        }
        .font(.system(size: 12, design: .monospaced))
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 44)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var sessionList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Sessions").font(.system(size: 10, weight: .medium, design: .monospaced))
                Spacer()
                Text(String(content.sessionCount)).monospacedDigit()
            }
            .foregroundStyle(.white.opacity(0.28))
            .padding(.horizontal, 10)
            .padding(.bottom, 18)
            if content.sessions.isEmpty {
                VStack(spacing: 8) {
                    Text("No sessions yet").foregroundStyle(.white.opacity(0.6))
                    Text("Connect an agent to get started").font(.system(size: 10)).foregroundStyle(.white.opacity(0.3))
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 2) {
                        ForEach(content.sessions, id: \.id) { session in
                            AgentSessionRow(session: session) { action(session.actionID) }
                        }
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            if content.pageCount > 1 {
                pageNavigation(older: "page:previous", newer: "page:next", text: "\(content.page + 1) / \(content.pageCount)")
                    .padding(.vertical, 10)
            }
        }
    }

    private func conversation(_ session: RillAgentSession) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { action("sessions") } label: {
                HStack(spacing: 9) {
                    Image(systemName: "chevron.left").font(.system(size: 10, weight: .semibold)).foregroundStyle(.white.opacity(0.4))
                    Text(session.title).font(.system(size: 12, weight: .semibold, design: .monospaced)).lineLimit(1)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to sessions")
            HStack(spacing: 6) {
                Text(session.project)
                Text("/").foregroundStyle(.white.opacity(0.18))
                Text(session.provider)
            }
            .font(.system(size: 9, design: .monospaced))
            .foregroundStyle(.white.opacity(0.3))
            .padding(.leading, 19)
            .padding(.top, 8)
            .padding(.bottom, 26)
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        ForEach(Array(content.messages.enumerated()), id: \.offset) { index, message in
                            AgentMessageView(message: message).id(index)
                        }
                        if content.messages.isEmpty {
                            Text("No messages yet").foregroundStyle(.white.opacity(0.3)).padding(.vertical, 20)
                        }
                        activity(session)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }
                .scrollBounceBehavior(.basedOnSize)
                .onChange(of: content.messages, initial: true) { _, messages in
                    if !messages.isEmpty { proxy.scrollTo(messages.count - 1, anchor: .bottom) }
                }
            }
            if content.conversationPageCount > 1 {
                pageNavigation(older: "chat:older", newer: "chat:newer", text: "\(content.conversationPage + 1) / \(content.conversationPageCount)")
                    .padding(.top, 12)
            }
        }
        .padding(.bottom, 18)
    }

    private func activity(_ session: RillAgentSession) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 8) {
                Circle().fill(session.phase.tint).frame(width: 4, height: 4).padding(.top, 5)
                Text(session.detail).font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4)).textSelection(.enabled)
            }
            if let allow = session.allowActionID, let deny = session.denyActionID {
                HStack(spacing: 10) {
                    Button { action(allow) } label: {
                        Label("Allow once", systemImage: "checkmark").frame(maxWidth: .infinity).padding(.vertical, 10)
                    }
                    .background(.white.opacity(0.12), in: Capsule())
                    Button { action(deny) } label: {
                        Text("Deny").padding(.horizontal, 18).padding(.vertical, 10)
                    }
                    .background(.white.opacity(0.05), in: Capsule())
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
            }
        }
        .padding(.top, 4)
    }

    private var footer: some View {
        VStack(spacing: 14) {
            Rectangle().fill(.white.opacity(0.08)).frame(height: 1)
            HStack(spacing: 18) {
                VStack(spacing: 12) {
                    ForEach(content.usage, id: \.title) { metric in
                        Button { usageDetail = metric.title } label: {
                            usageRow(metric)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(metric.title)
                        .accessibilityValue(metric.text)
                        .popover(isPresented: Binding(get: { usageDetail == metric.title }, set: { if !$0 { usageDetail = nil } })) {
                            MetricDetailView(metric: metric, packageDirectory: packageDirectory)
                        }
                    }
                }
                Menu {
                    Button("Connect Claude Code") { action("connect:claude") }
                    Button("Connect Codex") { action("connect:codex") }
                } label: {
                    Image(systemName: "slider.horizontal.3").font(.system(size: 12)).foregroundStyle(.white.opacity(0.35))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .accessibilityLabel("Agent settings")
            }
        }
    }

    private func usageRow(_ metric: RillMetricContent) -> some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                if let image = ExtensionImageCache.image(at: packageDirectory.appendingPathComponent(metric.icon)) {
                    Image(nsImage: image).resizable().scaledToFit().frame(width: 12, height: 12).opacity(0.55)
                }
                Text(metric.title.hasSuffix(" Usage") ? String(metric.title.dropLast(6)) : metric.title)
                    .lineLimit(1)
            }
            .foregroundStyle(.white.opacity(0.55))
            .frame(width: 84, alignment: .leading)
            if let value = metric.value {
                ProgressView(value: value)
                    .progressViewStyle(.linear)
                    .controlSize(.mini)
                    .tint(metric.accent.color.opacity(0.8))
                    .frame(maxWidth: .infinity)
            } else {
                Capsule().fill(.white.opacity(0.1)).frame(maxWidth: .infinity).frame(height: 3)
            }
            Text(metric.text).monospacedDigit().foregroundStyle(.white.opacity(0.65))
                .frame(width: 42, alignment: .trailing)
        }
        .font(.system(size: 10, design: .monospaced))
        .contentShape(Rectangle())
    }

    private func pageNavigation(older: String, newer: String, text: String) -> some View {
        HStack {
            Button { action(older) } label: { Image(systemName: "chevron.left") }
            Spacer()
            Text(text).foregroundStyle(.white.opacity(0.3))
            Spacer()
            Button { action(newer) } label: { Image(systemName: "chevron.right") }
        }
        .font(.system(size: 10, design: .monospaced))
        .buttonStyle(.plain)
        .foregroundStyle(.white.opacity(0.5))
    }
}

private struct AgentSessionRow: View {
    let session: RillAgentSession
    let action: () -> Void
    @State private var hovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Circle().fill(session.phase.tint).frame(width: 5, height: 5)
                    .opacity(session.phase == .working && !reduceMotion && !hovered ? 0.7 : 1)
                VStack(alignment: .leading, spacing: 5) {
                    Text(session.title).font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.92)).lineLimit(1)
                    Text(session.phase.caption).font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(session.phase.tint)
                }
                Spacer(minLength: 6)
                Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(hovered ? 0.65 : 0.2))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(.white.opacity(hovered ? 0.045 : 0), in: RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .accessibilityLabel("\(session.title), \(session.phase.caption), \(session.provider)")
    }
}

private struct AgentMessageView: View {
    let message: RillAgentMessage

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.isUser { Spacer(minLength: 38) }
            else { Circle().fill(.white.opacity(0.4)).frame(width: 4, height: 4).padding(.top, 7) }
            Text(.init(message.text))
                .font(.system(size: 12, weight: message.isUser ? .medium : .regular, design: .monospaced))
                .foregroundStyle(.white.opacity(message.isUser ? 0.95 : 0.8))
                .lineSpacing(5)
                .textSelection(.enabled)
                .padding(.horizontal, message.isUser ? 13 : 0)
                .padding(.vertical, message.isUser ? 11 : 0)
                .background(.white.opacity(message.isUser ? 0.13 : 0), in: RoundedRectangle(cornerRadius: 14))
            if !message.isUser { Spacer(minLength: 0) }
        }
        .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
    }
}

enum AgentActivityState: Equatable {
    case idle, working, completed, attention

    init(content: RillAgentDashboard) {
        if content.needsAttention { self = .attention }
        else if content.activeCount > 0 { self = .working }
        else if content.sessionCount > 0 && content.completedCount == content.sessionCount { self = .completed }
        else { self = .idle }
    }

    var color: Color {
        switch self {
        case .idle: .clear
        case .working: Color(red: 0.22, green: 0.59, blue: 1)
        case .completed: Color(red: 0.32, green: 0.87, blue: 0.49)
        case .attention: Color(red: 1, green: 0.28, blue: 0.27)
        }
    }

    var label: String {
        switch self {
        case .idle: "Idle"
        case .working: "Agents working"
        case .completed: "All agents finished"
        case .attention: "Attention required"
        }
    }

    func intensity(at elapsed: TimeInterval) -> Double {
        switch self {
        case .idle: return 0
        case .working: return 0.15
        case .completed: return 0.25 + 0.65 * (0.5 - 0.5 * cos(elapsed * .pi * 2 / 2.8))
        case .attention:
            let phase = elapsed.truncatingRemainder(dividingBy: 2.4)
            let pulse = phase < 0.32 ? phase : phase >= 0.48 && phase < 0.8 ? phase - 0.48 : nil
            return pulse.map { 0.16 + 0.84 * pow(sin($0 / 0.32 * .pi), 2) } ?? 0.16
        }
    }
}

struct AgentActivityIndicatorView: View {
    let content: RillAgentDashboard
    let horizontal: Bool
    let isVisible: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt = Date()
    @State private var completionVisible = true

    private var state: AgentActivityState { AgentActivityState(content: content) }
    private var visibleState: AgentActivityState { state == .completed && !completionVisible ? .idle : state }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !isVisible || reduceMotion || visibleState == .idle)) { context in
            GeometryReader { geometry in
                let elapsed = max(0, context.date.timeIntervalSince(startedAt))
                let length = horizontal ? geometry.size.width : geometry.size.height
                let position = elapsed.truncatingRemainder(dividingBy: 1.8) / 1.8 * (length + 28) - length / 2 - 14
                ZStack {
                    Capsule().fill(visibleState.color.opacity(reduceMotion ? 0.75 : visibleState.intensity(at: elapsed)))
                    if visibleState == .working && !reduceMotion {
                        Capsule()
                            .fill(LinearGradient(colors: [.clear, visibleState.color, .clear],
                                startPoint: horizontal ? .leading : .top, endPoint: horizontal ? .trailing : .bottom))
                            .frame(width: horizontal ? 28 : geometry.size.width, height: horizontal ? geometry.size.height : 28)
                            .offset(x: horizontal ? position : 0, y: horizontal ? 0 : position)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipShape(Capsule())
            }
        }
        .accessibilityLabel(visibleState.label)
        .task(id: state) {
            startedAt = Date()
            completionVisible = true
            guard state == .completed else { return }
            do { try await Task.sleep(for: .seconds(12)) } catch { return }
            completionVisible = false
        }
    }
}
