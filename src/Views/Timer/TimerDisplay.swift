// T033: TimerDisplay - Large countdown display component
// Session Timer - 计时器显示组件

import SwiftUI

/// 计时器显示组件
/// 显示大号倒计时、当前 Block 名称、组数进度
struct TimerDisplay: View {
    // MARK: - Properties
    
    let formattedTime: String
    let blockName: String
    let setProgress: String
    let statusText: String
    let isPaused: Bool
    let phase: TimerPhase
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 24) {
            // 状态指示器
            statusIndicator
            
            // Block 名称
            Text(blockName)
                .font(.title2)
                .fontWeight(.medium)
                .foregroundStyle(Color.textPrimary)
                .accessibilityLabel("当前练习：\(blockName)")
            
            // 大号倒计时
            countdownDisplay
            
            // 组数进度
            Text("第 \(setProgress) 组")
                .font(.title3)
                .foregroundStyle(Color.textSecondary)
                .accessibilityLabel("第\(setProgress)组")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(statusText)，\(blockName)，剩余\(formattedTime)，第\(setProgress)组")
    }
    
    // MARK: - Subviews
    
    /// 状态指示器
    private var statusIndicator: some View {
        Text(statusText)
            .font(.headline)
            .fontWeight(.bold)
            .foregroundStyle(isPaused ? Color.textPaused : Color.textPrimary)
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(statusBackgroundColor)
            )
            .opacity(isPaused ? 0.7 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isPaused)
    }
    
    /// 倒计时显示
    private var countdownDisplay: some View {
        Text(formattedTime)
            .font(.system(size: 128, weight: .bold, design: .monospaced))
            .foregroundStyle(Color.textPrimary)
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .opacity(isPaused ? 0.7 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isPaused)
            .contentTransition(.numericText())
            .animation(.linear(duration: 0.1), value: formattedTime)
            .accessibilityLabel("剩余时间 \(formattedTime)")
    }
    
    /// 状态背景颜色
    private var statusBackgroundColor: Color {
        if isPaused {
            return Color.yellow.opacity(0.3)
        }
        switch phase {
        case .work:
            return Color.orange.opacity(0.3)
        case .rest:
            return Color.green.opacity(0.3)
        }
    }
}

// MARK: - Preview

#Preview("Timer Display - Work") {
    ZStack {
        Color.workBackground
            .ignoresSafeArea()
        
        TimerDisplay(
            formattedTime: "01:30",
            blockName: "深蹲",
            setProgress: "2/3",
            statusText: "WORK",
            isPaused: false,
            phase: .work
        )
    }
}

#Preview("Timer Display - Rest") {
    ZStack {
        Color.restBackground
            .ignoresSafeArea()
        
        TimerDisplay(
            formattedTime: "00:10",
            blockName: "深蹲",
            setProgress: "2/3",
            statusText: "REST",
            isPaused: false,
            phase: .rest
        )
    }
}

#Preview("Timer Display - Paused") {
    ZStack {
        Color.workBackground
            .ignoresSafeArea()
        
        TimerDisplay(
            formattedTime: "01:30",
            blockName: "深蹲",
            setProgress: "2/3",
            statusText: "PAUSED",
            isPaused: true,
            phase: .work
        )
    }
}
