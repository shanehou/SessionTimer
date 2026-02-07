// T031: DurationPicker - Minutes:Seconds picker component
// Session Timer - 时长选择器组件

import SwiftUI

/// 时长选择器组件
/// 支持分钟:秒 格式的输入
struct DurationPicker: View {
    // MARK: - Properties
    
    /// 绑定的秒数
    @Binding var seconds: Int
    
    /// 标签（用于辅助功能）
    let label: String
    
    /// 是否显示选择器
    @State private var showPicker: Bool = false
    
    // MARK: - Computed Properties
    
    /// 分钟数
    private var minutes: Int {
        seconds / 60
    }
    
    /// 秒数（除去分钟后的余数）
    private var remainingSeconds: Int {
        seconds % 60
    }
    
    /// 格式化显示
    private var formattedDuration: String {
        String(format: "%02d:%02d", minutes, remainingSeconds)
    }
    
    // MARK: - Body
    
    var body: some View {
        Button {
            showPicker = true
        } label: {
            Text(formattedDuration)
                .font(.title3.monospacedDigit())
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue("\(minutes)分\(remainingSeconds)秒")
        .sheet(isPresented: $showPicker) {
            DurationPickerSheet(
                seconds: $seconds,
                label: label,
                isPresented: $showPicker
            )
            .presentationDetents([.height(300)])
        }
    }
}

/// 时长选择器 Sheet
struct DurationPickerSheet: View {
    // MARK: - Properties
    
    @Binding var seconds: Int
    let label: String
    @Binding var isPresented: Bool
    
    /// 临时存储的分钟数
    @State private var tempMinutes: Int = 0
    
    /// 临时存储的秒数
    @State private var tempSeconds: Int = 0
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("设置\(label)")
                    .font(.headline)
                
                HStack(spacing: 0) {
                    // 分钟选择器
                    Picker("分钟", selection: $tempMinutes) {
                        ForEach(0..<100, id: \.self) { minute in
                            Text("\(minute)").tag(minute)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 80)
                    .clipped()
                    
                    Text("分")
                        .font(.headline)
                    
                    // 秒选择器
                    Picker("秒", selection: $tempSeconds) {
                        ForEach(0..<60, id: \.self) { second in
                            Text(String(format: "%02d", second)).tag(second)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 80)
                    .clipped()
                    
                    Text("秒")
                        .font(.headline)
                }
                
                // 预设快捷按钮
                presetButtons
                
                Spacer()
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("确定") {
                        seconds = tempMinutes * 60 + tempSeconds
                        isPresented = false
                    }
                }
            }
        }
        .onAppear {
            tempMinutes = seconds / 60
            tempSeconds = seconds % 60
        }
    }
    
    // MARK: - Preset Buttons
    
    private var presetButtons: some View {
        VStack(spacing: 12) {
            Text("快捷设置")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 12) {
                presetButton(seconds: 10, label: "10秒")
                presetButton(seconds: 30, label: "30秒")
                presetButton(seconds: 60, label: "1分钟")
                presetButton(seconds: 120, label: "2分钟")
            }
            
            HStack(spacing: 12) {
                presetButton(seconds: 180, label: "3分钟")
                presetButton(seconds: 300, label: "5分钟")
                presetButton(seconds: 600, label: "10分钟")
            }
        }
    }
    
    private func presetButton(seconds: Int, label: String) -> some View {
        Button {
            tempMinutes = seconds / 60
            tempSeconds = seconds % 60
        } label: {
            Text(label)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Duration Picker") {
    struct PreviewWrapper: View {
        @State private var duration: Int = 90
        
        var body: some View {
            VStack(spacing: 20) {
                Text("当前值: \(duration)秒")
                
                DurationPicker(seconds: $duration, label: "练习时间")
            }
            .padding()
        }
    }
    
    return PreviewWrapper()
}
