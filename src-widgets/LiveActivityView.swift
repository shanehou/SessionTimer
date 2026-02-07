// T055: LiveActivityView - Lock Screen Live Activity UI
// Session Timer - 锁屏 Live Activity 界面

import ActivityKit
import SwiftUI
import WidgetKit

/// 锁屏 Live Activity 视图
struct LiveActivityView: View {
    let context: ActivityViewContext<SessionTimerAttributes>
    
    private var state: SessionTimerAttributes.ContentState {
        context.state
    }
    
    private var isWork: Bool {
        state.isWorkPhase
    }
    
    private var phaseColor: Color {
        isWork ? .orange : .green
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // 左侧：阶段指示
            VStack(alignment: .leading, spacing: 4) {
                // 阶段标签
                Text(state.statusText)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(state.isPaused ? .yellow : phaseColor)
                
                // 大倒计时 - 使用 timerInterval 实现系统级精确倒计时
                if state.isPaused {
                    Text(state.formattedTime)
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                } else {
                    Text(timerInterval: state.timerInterval, countsDown: true)
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                }
                
                // Block 名称
                Text(state.currentBlockName)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
            }
            
            Spacer()
            
            // 右侧：进度信息
            VStack(alignment: .trailing, spacing: 8) {
                // Session 名称
                Text(context.attributes.sessionName)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
                
                // 组进度：圆形指示器
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.2), lineWidth: 3)
                    
                    Circle()
                        .trim(from: 0, to: setProgress)
                        .stroke(phaseColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 0) {
                        Text(state.setProgressText)
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                        
                        Text("SET")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .frame(width: 50, height: 50)
                
                // Block 进度
                Text("Block \(state.blockProgressText(totalBlocks: context.attributes.totalBlocks))")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(16)
        .activityBackgroundTint(isWork ? .black : Color(red: 0.05, green: 0.2, blue: 0.05))
    }
    
    // MARK: - Computed
    
    private var setProgress: Double {
        guard state.totalSets > 0 else { return 0 }
        return Double(state.currentSet) / Double(state.totalSets)
    }
}

// MARK: - Preview

#Preview("Live Activity - Work", as: .content, using: SessionTimerAttributes(
    sessionName: "练腿日",
    totalBlocks: 3
)) {
    SessionTimerLiveActivityWidget()
} contentStates: {
    SessionTimerAttributes.ContentState(
        currentBlockName: "深蹲",
        currentBlockIndex: 0,
        currentSet: 2,
        totalSets: 3,
        remainingSeconds: 25,
        timerEndDate: Date().addingTimeInterval(25),
        phase: "work",
        isPaused: false
    )
    SessionTimerAttributes.ContentState(
        currentBlockName: "箭步蹲",
        currentBlockIndex: 1,
        currentSet: 1,
        totalSets: 4,
        remainingSeconds: 8,
        timerEndDate: Date().addingTimeInterval(8),
        phase: "rest",
        isPaused: false
    )
    SessionTimerAttributes.ContentState(
        currentBlockName: "深蹲",
        currentBlockIndex: 0,
        currentSet: 2,
        totalSets: 3,
        remainingSeconds: 15,
        timerEndDate: Date().addingTimeInterval(15),
        phase: "work",
        isPaused: true
    )
}
