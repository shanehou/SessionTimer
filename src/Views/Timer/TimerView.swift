// T034: TimerView - Full-screen timer with gesture support
// Session Timer - 计时器全屏视图

import SwiftUI

/// 计时器视图
/// 支持全屏手势控制：单击暂停/继续，双击跳过，长按结束
struct TimerView: View {
    // MARK: - Environment
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    
    // 使用 @State 持有 ViewModel 的所有权，确保不会被重新创建
    @State private var viewModel: TimerViewModel
    @State private var showStopConfirmation: Bool = false
    @State private var showAdjustmentSheet: Bool = false
    
    // MARK: - Initializer
    
    init(session: Session) {
        // 使用 _viewModel 直接初始化 State wrapper
        self._viewModel = State(wrappedValue: TimerViewModel(session: session))
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // 背景颜色
            viewModel.backgroundColor
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.3), value: viewModel.currentPhase)
                .animation(.easeInOut(duration: 0.3), value: viewModel.isPaused)
            
            // 主内容
            VStack {
                // 顶部信息栏
                topBar
                
                Spacer()
                
                // 计时器显示
                TimerDisplay(
                    formattedTime: viewModel.formattedTime,
                    blockName: viewModel.currentBlockName,
                    setProgress: viewModel.setProgressText,
                    statusText: viewModel.statusText,
                    isPaused: viewModel.isPaused,
                    phase: viewModel.currentPhase
                )
                
                Spacer()
                
                // 底部提示
                bottomHints
            }
            .padding()
            
            // 完成覆盖层
            if viewModel.isCompleted {
                SessionCompleteView(
                    session: viewModel.session,
                    onDismiss: {
                        viewModel.stop()
                        dismiss()
                    }
                )
                .transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        // 双击手势（必须在单击之前）
        .onTapGesture(count: 2) {
            handleDoubleTap()
        }
        // 单击手势
        .onTapGesture(count: 1) {
            handleSingleTap()
        }
        // 长按手势
        .onLongPressGesture(minimumDuration: 1.0) {
            handleLongPress()
        }
        // 上滑手势打开调整面板
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    if value.translation.height < -50 {
                        showAdjustmentSheet = true
                    }
                }
        )
        .navigationBarHidden(true)
        .statusBar(hidden: true)
        .persistentSystemOverlays(.hidden)
        .onAppear {
            viewModel.start()
        }
        .onDisappear {
            if !viewModel.isCompleted {
                viewModel.stop()
            }
        }
        .confirmationDialog(
            "确定要结束练习吗？",
            isPresented: $showStopConfirmation,
            titleVisibility: .visible
        ) {
            Button("结束练习", role: .destructive) {
                viewModel.stop()
                dismiss()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("当前进度将不会保存")
        }
        .sheet(isPresented: $showAdjustmentSheet) {
            AdjustmentSheet(viewModel: viewModel)
                .presentationDetents([.height(250)])
        }
    }
    
    // MARK: - Subviews
    
    /// 顶部信息栏
    private var topBar: some View {
        HStack {
            // 返回按钮
            Button {
                showStopConfirmation = true
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.textSecondary)
            }
            
            Spacer()
            
            // Session 名称和 Block 进度
            VStack(spacing: 2) {
                Text(viewModel.session.name)
                    .font(.headline)
                    .foregroundStyle(Color.textPrimary)
                
                Text("Block \(viewModel.blockProgressText)")
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
            }
            
            Spacer()
            
            // 调整按钮
            Button {
                showAdjustmentSheet = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.title2)
                    .foregroundStyle(Color.textSecondary)
            }
        }
    }
    
    /// 底部提示
    private var bottomHints: some View {
        VStack(spacing: 8) {
            Text("单击暂停 · 双击跳过 · 长按结束")
                .font(.caption)
                .foregroundStyle(Color.textSecondary)
            
            Text("上滑打开更多选项")
                .font(.caption2)
                .foregroundStyle(Color.textSecondary.opacity(0.6))
        }
        .opacity(viewModel.isPaused ? 1.0 : 0.5)
    }
    
    // MARK: - Gesture Handlers
    
    /// 处理单击 - 暂停/继续
    private func handleSingleTap() {
        guard !viewModel.isCompleted else { return }
        viewModel.togglePause()
    }
    
    /// 处理双击 - 跳过当前阶段
    private func handleDoubleTap() {
        guard !viewModel.isCompleted else { return }
        viewModel.skip()
    }
    
    /// 处理长按 - 结束 Session
    private func handleLongPress() {
        guard !viewModel.isCompleted else { return }
        showStopConfirmation = true
    }
}

// MARK: - Adjustment Sheet

/// 运行时调整面板
struct AdjustmentSheet: View {
    let viewModel: TimerViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                // 加一组
                Button {
                    viewModel.addSet()
                    dismiss()
                } label: {
                    Label("加一组", systemImage: "plus.circle")
                }
                
                // 跳过休息（仅在休息阶段可用）
                if viewModel.currentPhase == .rest {
                    Button {
                        viewModel.skipRest()
                        dismiss()
                    } label: {
                        Label("跳过休息", systemImage: "forward.fill")
                    }
                    
                    Button {
                        viewModel.extendRest()
                        dismiss()
                    } label: {
                        Label("延长休息 30 秒", systemImage: "clock.badge.plus")
                    }
                }
                
                // 跳过当前阶段
                Button {
                    viewModel.skip()
                    dismiss()
                } label: {
                    Label("跳过当前阶段", systemImage: "forward.end")
                }
            }
            .navigationTitle("调整")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Timer View - Work") {
    let block = Block(name: "深蹲", setCount: 3, workDuration: 30, restDuration: 10)
    let session = Session(name: "练腿日", blocks: [block])
    
    return TimerView(session: session)
}

#Preview("Timer View - Multiple Blocks") {
    let block1 = Block(name: "深蹲", setCount: 3, workDuration: 5, restDuration: 3)
    let block2 = Block(name: "箭步蹲", setCount: 3, workDuration: 5, restDuration: 3)
    block2.orderIndex = 1
    
    let session = Session(name: "练腿日", blocks: [block1, block2])
    
    return TimerView(session: session)
}
