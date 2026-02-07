// T032: SessionEditorView - Session creation/editing form
// Session Timer - Session 编辑视图

import SwiftUI
import SwiftData

/// Session 编辑视图
struct SessionEditorView: View {
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    
    @State private var viewModel: SessionEditorViewModel
    
    /// 完成回调
    var onSave: ((Session) -> Void)?
    
    // MARK: - Initializers
    
    /// 创建模式
    init(onSave: ((Session) -> Void)? = nil) {
        self._viewModel = State(initialValue: SessionEditorViewModel())
        self.onSave = onSave
    }
    
    /// 编辑模式
    init(session: Session, onSave: ((Session) -> Void)? = nil) {
        self._viewModel = State(initialValue: SessionEditorViewModel(session: session))
        self.onSave = onSave
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                // Session 名称
                sessionNameSection
                
                // Block 列表
                blocksSection
                
                // 摘要信息
                summarySection
            }
            .navigationTitle(viewModel.isEditing ? "编辑练习计划" : "新建练习计划")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveSession()
                    }
                    .disabled(!viewModel.canSave)
                }
            }
            .alert(
                "保存失败",
                isPresented: $viewModel.showValidationError,
                presenting: viewModel.validationError
            ) { _ in
                Button("好的") {
                    viewModel.clearValidationError()
                }
            } message: { error in
                VStack {
                    Text(error.localizedDescription)
                    if let suggestion = error.recoverySuggestion {
                        Text(suggestion)
                            .font(.caption)
                    }
                }
            }
        }
    }
    
    // MARK: - Sections
    
    /// Session 名称输入区
    private var sessionNameSection: some View {
        Section {
            TextField("练习计划名称", text: $viewModel.name)
                .font(.headline)
        } header: {
            Text("名称")
        } footer: {
            Text("给你的练习计划起个名字，如「练腿日」或「音阶练习」")
        }
    }
    
    /// Block 列表区
    private var blocksSection: some View {
        Section {
            ForEach(viewModel.blocks) { block in
                BlockEditorRow(block: block)
            }
            .onDelete { offsets in
                viewModel.deleteBlocks(at: offsets)
            }
            .onMove { source, destination in
                viewModel.moveBlock(from: source, to: destination)
            }
            
            // 添加 Block 按钮
            Button {
                withAnimation {
                    viewModel.addBlock()
                }
            } label: {
                Label("添加练习项目", systemImage: "plus.circle.fill")
            }
            .frame(minHeight: 44)
            .accessibilityHint("添加一个新的练习项目到当前计划")
        } header: {
            HStack {
                Text("练习项目")
                Spacer()
                EditButton()
                    .font(.caption)
            }
        } footer: {
            Text("每个练习项目可以设置组数、练习时间和休息时间")
        }
    }
    
    /// 摘要信息区
    private var summarySection: some View {
        Section {
            HStack {
                Text("练习项目")
                Spacer()
                Text("\(viewModel.blocks.count) 个")
                    .foregroundStyle(.secondary)
            }
            
            HStack {
                Text("总组数")
                Spacer()
                Text("\(viewModel.totalSets) 组")
                    .foregroundStyle(.secondary)
            }
            
            HStack {
                Text("预计时长")
                Spacer()
                Text(viewModel.formattedTotalDuration)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("摘要")
        }
    }
    
    // MARK: - Actions
    
    /// 保存 Session
    private func saveSession() {
        do {
            let session = try viewModel.save(modelContext: modelContext)
            onSave?(session)
            dismiss()
        } catch {
            // 验证错误已经在 viewModel 中处理
        }
    }
}

// MARK: - Preview

#Preview("Create Session") {
    SessionEditorView()
        .modelContainer(for: [Session.self, Block.self], inMemory: true)
}

#Preview("Edit Session") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Session.self, Block.self, configurations: config)
    
    let block = Block(name: "深蹲", setCount: 3, workDuration: 30, restDuration: 10)
    let session = Session(name: "练腿日", blocks: [block])
    container.mainContext.insert(session)
    
    return SessionEditorView(session: session)
        .modelContainer(container)
}
