// T041: SessionDetailView - Session detail/preview view
// Session Timer - Session 详情视图

import SwiftUI
import SwiftData

/// Session 详情视图
/// 显示 Session 完整信息，支持编辑、删除、开始
struct SessionDetailView: View {
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    let session: Session
    let onStart: () -> Void
    
    // MARK: - State
    
    @State private var showEditSheet: Bool = false
    @State private var showDeleteConfirmation: Bool = false
    
    // MARK: - Body
    
    var body: some View {
        List {
            // 头部摘要
            headerSection
            
            // Block 列表
            blocksSection
            
            // 操作区域
            actionsSection
        }
        .navigationTitle(session.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("编辑") {
                    showEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            SessionEditorView(session: session)
        }
        .alert("确认删除", isPresented: $showDeleteConfirmation) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                deleteSession()
            }
        } message: {
            Text("确定要删除「\(session.name)」吗？此操作不可撤销。")
        }
    }
    
    // MARK: - Sections
    
    /// 头部摘要区
    private var headerSection: some View {
        Section {
            // 统计信息
            HStack {
                StatCard(
                    title: "项目",
                    value: "\(session.blocks.count)",
                    icon: "square.stack.3d.up"
                )
                
                StatCard(
                    title: "总组数",
                    value: "\(session.totalSets)",
                    icon: "repeat"
                )
                
                StatCard(
                    title: "时长",
                    value: session.formattedTotalDuration,
                    icon: "clock"
                )
            }
            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            .listRowBackground(Color.clear)
            
            // 开始按钮
            Button {
                onStart()
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                    Text("开始练习")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 16, trailing: 16))
            .listRowBackground(Color.clear)
            .accessibilityLabel("开始练习\(session.name)")
            .accessibilityHint("启动计时器开始此练习计划")
        }
    }
    
    /// Block 列表区
    private var blocksSection: some View {
        Section {
            ForEach(session.sortedBlocks, id: \.id) { block in
                BlockDetailRow(block: block)
            }
        } header: {
            Text("练习项目")
        }
    }
    
    /// 操作区域
    private var actionsSection: some View {
        Section {
            // 收藏按钮
            Button {
                withAnimation {
                    session.isFavorite.toggle()
                }
            } label: {
                Label(
                    session.isFavorite ? "取消收藏" : "添加到收藏",
                    systemImage: session.isFavorite ? "star.fill" : "star"
                )
                .foregroundStyle(session.isFavorite ? .yellow : .primary)
            }
            .accessibilityLabel(session.isFavorite ? "取消收藏" : "添加到收藏")
            .accessibilityHint(session.isFavorite ? "将此练习计划从收藏中移除" : "将此练习计划添加到收藏")
            
            // 删除按钮
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("删除练习计划", systemImage: "trash")
            }
            .accessibilityLabel("删除练习计划")
            .accessibilityHint("永久删除此练习计划，此操作不可撤销")
        } header: {
            Text("操作")
        } footer: {
            if let lastUsed = session.formattedLastUsedAt {
                Text("上次使用: \(lastUsed)")
            } else {
                Text("创建于 \(session.formattedCreatedAt)")
            }
        }
    }
    
    // MARK: - Actions
    
    /// 删除 Session
    private func deleteSession() {
        modelContext.delete(session)
        dismiss()
    }
}

// MARK: - Stat Card

/// 统计卡片组件
private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title)：\(value)")
    }
}

// MARK: - Block Detail Row

/// Block 详情行组件
private struct BlockDetailRow: View {
    let block: Block
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Block 名称
            Text(block.name)
                .font(.headline)
            
            // Block 详情
            HStack(spacing: 16) {
                Label("\(block.setCount) 组", systemImage: "repeat")
                
                Label(block.workDuration.formatted_MMSS, systemImage: "flame")
                    .foregroundStyle(.orange)
                
                Label(block.restDuration.formatted_MMSS, systemImage: "pause.circle")
                    .foregroundStyle(.green)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            
            // Block 时长
            Text("共 \(block.formattedTotalDuration)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(block.name)，\(block.setCount)组，练习\(block.workDuration.formatted_MMSS)，休息\(block.restDuration.formatted_MMSS)，共\(block.formattedTotalDuration)")
    }
}

// MARK: - Preview

#Preview("Session Detail") {
    let block1 = Block(name: "深蹲", setCount: 3, workDuration: 30, restDuration: 10)
    let block2 = Block(name: "箭步蹲", setCount: 3, workDuration: 30, restDuration: 10)
    block2.orderIndex = 1
    let block3 = Block(name: "腿举", setCount: 4, workDuration: 45, restDuration: 15)
    block3.orderIndex = 2
    
    let session = Session(name: "练腿日", blocks: [block1, block2, block3])
    session.isFavorite = true
    session.lastUsedAt = Date().addingTimeInterval(-7200)
    
    return NavigationStack {
        SessionDetailView(session: session, onStart: { print("Started") })
    }
    .modelContainer(for: [Session.self, Block.self], inMemory: true)
}
