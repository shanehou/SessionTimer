// T035: SessionCompleteView - Completion celebration screen
// Session Timer - Session 完成视图

import SwiftUI

/// Session 完成视图
struct SessionCompleteView: View {
    // MARK: - Properties
    
    let session: Session
    let onDismiss: () -> Void
    
    // MARK: - Animation State
    
    @State private var showCheckmark: Bool = false
    @State private var showContent: Bool = false
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // 背景
            Color.black.opacity(0.95)
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // 完成图标
                completionIcon
                
                // 标题
                VStack(spacing: 8) {
                    Text("太棒了！")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    
                    Text("练习完成")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)
                
                // 统计信息
                statsView
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)
                
                Spacer()
                
                // 完成按钮
                Button {
                    onDismiss()
                } label: {
                    Text("完成")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 32)
                .opacity(showContent ? 1 : 0)
                .frame(minHeight: 56)
                .accessibilityLabel("完成")
                .accessibilityHint("返回主界面")
            }
            .padding()
        }
        .onAppear {
            // 触发动画
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                showCheckmark = true
            }
            
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                showContent = true
            }
        }
    }
    
    // MARK: - Subviews
    
    /// 完成图标
    private var completionIcon: some View {
        ZStack {
            // 背景圆
            Circle()
                .fill(Color.green)
                .frame(width: 120, height: 120)
                .scaleEffect(showCheckmark ? 1 : 0)
            
            // 勾选图标
            Image(systemName: "checkmark")
                .font(.system(size: 60, weight: .bold))
                .foregroundStyle(.white)
                .scaleEffect(showCheckmark ? 1 : 0)
        }
    }
    
    /// 统计视图
    private var statsView: some View {
        VStack(spacing: 16) {
            // Session 名称
            Text(session.name)
                .font(.headline)
                .foregroundStyle(.white)
            
            // 统计卡片
            HStack(spacing: 24) {
                statItem(
                    value: "\(session.blocks.count)",
                    label: "练习项目",
                    icon: "rectangle.stack"
                )
                
                statItem(
                    value: "\(session.totalSets)",
                    label: "总组数",
                    icon: "repeat"
                )
                
                statItem(
                    value: session.formattedTotalDuration,
                    label: "总时长",
                    icon: "clock"
                )
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
    
    /// 统计项
    private func statItem(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.green)
            
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(minWidth: 80)
    }
}

// MARK: - Preview

#Preview("Session Complete") {
    let block1 = Block(name: "深蹲", setCount: 3, workDuration: 30, restDuration: 10)
    let block2 = Block(name: "箭步蹲", setCount: 3, workDuration: 30, restDuration: 10)
    block2.orderIndex = 1
    
    let session = Session(name: "练腿日", blocks: [block1, block2])
    
    return SessionCompleteView(session: session) {
        print("Dismissed")
    }
}
