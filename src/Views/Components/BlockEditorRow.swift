// T030: BlockEditorRow - Reusable Block editing row component
// Session Timer - Block 编辑行组件

import SwiftUI

/// Block 编辑行组件
struct BlockEditorRow: View {
    // MARK: - Properties
    
    @Bindable var block: EditableBlock
    
    /// 是否展开详细设置
    @State private var isExpanded: Bool = true
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Block 名称输入
            HStack {
                TextField("练习名称", text: $block.name)
                    .font(.headline)
                
                Spacer()
                
                // 展开/折叠按钮
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            if isExpanded {
                // 详细设置
                VStack(spacing: 16) {
                    // 组数设置
                    setCountRow
                    
                    Divider()
                    
                    // 练习时间设置
                    workDurationRow
                    
                    Divider()
                    
                    // 休息时间设置
                    restDurationRow
                    
                    Divider()
                    
                    // 语音播报设置
                    announcementSection
                }
                .padding(.top, 4)
            }
            
            // 摘要信息
            HStack {
                Text("总时长")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(block.totalDuration.formattedDuration)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Subviews
    
    /// 组数设置行
    private var setCountRow: some View {
        HStack {
            Label("组数", systemImage: "repeat")
                .font(.subheadline)
            
            Spacer()
            
            // 减少按钮
            Button {
                if block.setCount > 1 {
                    block.setCount -= 1
                }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(block.setCount > 1 ? .blue : .gray)
            }
            .buttonStyle(.plain)
            .disabled(block.setCount <= 1)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel("减少组数")
            .accessibilityHint("当前\(block.setCount)组")
            
            // 组数显示
            Text("\(block.setCount)")
                .font(.title3.monospacedDigit())
                .frame(minWidth: 40)
                .accessibilityLabel("\(block.setCount)组")
            
            // 增加按钮
            Button {
                if block.setCount < 99 {
                    block.setCount += 1
                }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(block.setCount < 99 ? .blue : .gray)
            }
            .buttonStyle(.plain)
            .disabled(block.setCount >= 99)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel("增加组数")
            .accessibilityHint("当前\(block.setCount)组")
        }
    }
    
    /// 练习时间设置行
    private var workDurationRow: some View {
        HStack {
            Label("练习", systemImage: "flame.fill")
                .font(.subheadline)
                .foregroundStyle(.primary)
            
            Spacer()
            
            DurationPicker(
                seconds: $block.workDuration,
                label: "练习时间"
            )
        }
    }
    
    /// 休息时间设置行
    private var restDurationRow: some View {
        HStack {
            Label("休息", systemImage: "leaf.fill")
                .font(.subheadline)
                .foregroundStyle(.green)
            
            Spacer()
            
            DurationPicker(
                seconds: $block.restDuration,
                label: "休息时间"
            )
        }
    }
    
    /// 语音播报设置区域
    @State private var isAnnouncementExpanded: Bool = false
    
    private var announcementSection: some View {
        DisclosureGroup("语音播报", isExpanded: $isAnnouncementExpanded) {
            VStack(spacing: 12) {
                announcementField(
                    title: "开始播报",
                    text: $block.announcementStart,
                    placeholder: "默认：\(block.name)"
                )
                
                announcementField(
                    title: "休息播报",
                    text: $block.announcementRest,
                    placeholder: "默认：休息"
                )
                
                announcementField(
                    title: "继续播报",
                    text: $block.announcementContinue,
                    placeholder: "默认：继续"
                )
            }
            .padding(.top, 8)
        }
        .font(.subheadline)
    }
    
    private func announcementField(title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .font(.subheadline)
                .textFieldStyle(.roundedBorder)
            if text.wrappedValue.count > 50 {
                Text("建议文本不超过 50 个字符")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
    }
}

// MARK: - Preview

#Preview("Block Editor Row") {
    List {
        BlockEditorRow(block: EditableBlock(
            name: "深蹲",
            setCount: 3,
            workDuration: 30,
            restDuration: 10
        ))
        
        BlockEditorRow(block: EditableBlock(
            name: "箭步蹲",
            setCount: 4,
            workDuration: 45,
            restDuration: 15
        ))
    }
}
