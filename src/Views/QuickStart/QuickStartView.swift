// Session Timer - 快速开始配置页面

import SwiftUI

/// 快速开始配置视图（Sheet 呈现）
struct QuickStartView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var viewModel = QuickStartViewModel()
    
    /// 创建 Session 后的回调
    var onStart: (Session) -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 16) {
                        preparingSection
                        blocksSection
                        addBlockButton
                    }
                    .padding()
                }
                
                startButton
            }
            .navigationTitle("快速开始")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Sections
    
    private var preparingSection: some View {
        HStack {
            Label("预备时间", systemImage: "timer")
                .font(.headline)
            
            Spacer()
            
            Stepper(
                "\(viewModel.preparingDuration) 秒",
                value: $viewModel.preparingDuration,
                in: 0...30
            )
            .frame(width: 160)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var blocksSection: some View {
        ForEach(Array(viewModel.blocks.enumerated()), id: \.element.id) { index, block in
            QuickStartBlockCard(
                block: block,
                showDelete: viewModel.blocks.count > 1,
                onDelete: {
                    withAnimation {
                        viewModel.removeBlock(at: index)
                    }
                }
            )
        }
    }
    
    private var addBlockButton: some View {
        Button {
            withAnimation {
                viewModel.addBlock()
            }
        } label: {
            Label("添加项目", systemImage: "plus.circle.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private var startButton: some View {
        Button {
            let session = viewModel.createSession()
            dismiss()
            onStart(session)
        } label: {
            Text("开始训练")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(viewModel.canStart ? Color.blue : Color.gray)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .disabled(!viewModel.canStart)
        .padding()
    }
}

// MARK: - Block Card

struct QuickStartBlockCard: View {
    @Bindable var block: EditableQuickStartBlock
    let showDelete: Bool
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题行
            HStack {
                TextField("项目名称", text: $block.name)
                    .font(.headline)
                
                if showDelete {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Divider()
            
            // 组数
            Stepper("组数：\(block.setCount)", value: $block.setCount, in: 1...99)
            
            // 练习时长
            HStack {
                Text("练习时长")
                Spacer()
                DurationPicker(seconds: $block.workDuration, label: "练习时长")
            }
            
            // 休息时长
            HStack {
                Text("休息时长")
                Spacer()
                DurationPicker(seconds: $block.restDuration, label: "休息时长")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Preview

#Preview("Quick Start View") {
    QuickStartView { session in
        print("Starting session: \(session.name)")
    }
}
