// T056: DynamicIslandView - Dynamic Island views
// Session Timer - 灵动岛界面

import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Compact Leading (左侧紧凑)

/// 灵动岛紧凑模式 - 左侧：阶段颜色指示 + 图标
struct DynamicIslandCompactLeadingView: View {
    let context: ActivityViewContext<SessionTimerAttributes>
    
    private var isWork: Bool {
        context.state.isWorkPhase
    }
    
    var body: some View {
        HStack(spacing: 4) {
            // 阶段颜色圆点
            Circle()
                .fill(isWork ? Color.orange : Color.green)
                .frame(width: 8, height: 8)
            
            // 阶段文字
            Text(context.state.isPaused ? "⏸" : (isWork ? "W" : "R"))
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(isWork ? .orange : .green)
        }
    }
}

// MARK: - Compact Trailing (右侧紧凑)

/// 灵动岛紧凑模式 - 右侧：倒计时
struct DynamicIslandCompactTrailingView: View {
    let context: ActivityViewContext<SessionTimerAttributes>
    
    var body: some View {
        if context.state.isPaused {
            Text(context.state.formattedTime)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
        } else {
            Text(timerInterval: context.state.timerInterval, countsDown: true)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .monospacedDigit()
                .frame(minWidth: 48)
        }
    }
}

// MARK: - Minimal (最小化)

/// 灵动岛最小模式 - 仅显示阶段颜色的饼图进度
struct DynamicIslandMinimalView: View {
    let context: ActivityViewContext<SessionTimerAttributes>
    
    private var isWork: Bool {
        context.state.isWorkPhase
    }
    
    var body: some View {
        ZStack {
            // 进度环
            Circle()
                .stroke(.white.opacity(0.2), lineWidth: 2)
            
            Circle()
                .trim(from: 0, to: setProgress)
                .stroke(
                    isWork ? Color.orange : Color.green,
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            
            // 中心阶段指示
            Text(context.state.isPaused ? "⏸" : (isWork ? "W" : "R"))
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(isWork ? .orange : .green)
        }
    }
    
    private var setProgress: Double {
        guard context.state.totalSets > 0 else { return 0 }
        return Double(context.state.currentSet) / Double(context.state.totalSets)
    }
}

// MARK: - Expanded Leading

/// 灵动岛展开模式 - 左侧：阶段信息
struct DynamicIslandExpandedLeadingView: View {
    let context: ActivityViewContext<SessionTimerAttributes>
    
    private var isWork: Bool {
        context.state.isWorkPhase
    }
    
    private var phaseColor: Color {
        isWork ? .orange : .green
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(context.state.statusText)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(context.state.isPaused ? .yellow : phaseColor)
            
            Text(context.state.currentBlockName)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
        }
    }
}

// MARK: - Expanded Trailing

/// 灵动岛展开模式 - 右侧：组进度
struct DynamicIslandExpandedTrailingView: View {
    let context: ActivityViewContext<SessionTimerAttributes>
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("SET \(context.state.setProgressText)")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            
            Text("Block \(context.state.blockProgressText(totalBlocks: context.attributes.totalBlocks))")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}

// MARK: - Expanded Center

/// 灵动岛展开模式 - 中央：大倒计时
struct DynamicIslandExpandedCenterView: View {
    let context: ActivityViewContext<SessionTimerAttributes>
    
    var body: some View {
        if context.state.isPaused {
            Text(context.state.formattedTime)
                .font(.system(size: 36, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
        } else {
            Text(timerInterval: context.state.timerInterval, countsDown: true)
                .font(.system(size: 36, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
    }
}

// MARK: - Expanded Bottom

/// 灵动岛展开模式 - 底部：进度条 + Session 名称
struct DynamicIslandExpandedBottomView: View {
    let context: ActivityViewContext<SessionTimerAttributes>
    
    private var isWork: Bool {
        context.state.isWorkPhase
    }
    
    private var phaseColor: Color {
        isWork ? .orange : .green
    }
    
    var body: some View {
        VStack(spacing: 6) {
            // 组进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white.opacity(0.15))
                    
                    // 前景
                    RoundedRectangle(cornerRadius: 2)
                        .fill(phaseColor)
                        .frame(width: geometry.size.width * setProgress)
                }
            }
            .frame(height: 4)
            
            // Session 名称
            Text(context.attributes.sessionName)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
                .lineLimit(1)
        }
    }
    
    private var setProgress: Double {
        guard context.state.totalSets > 0 else { return 0 }
        return Double(context.state.currentSet) / Double(context.state.totalSets)
    }
}
