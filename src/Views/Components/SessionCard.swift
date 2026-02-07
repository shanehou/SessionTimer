// T039: SessionCard - Reusable Session card component
// Session Timer - Session 卡片组件

import SwiftUI

/// Session 卡片组件
/// 显示 Session 名称、总时长、Block 数量、收藏状态
struct SessionCard: View {
    // MARK: - Properties
    
    let session: Session
    let onTap: () -> Void
    let onStart: () -> Void
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 12) {
            // 主要内容
            VStack(alignment: .leading, spacing: 4) {
                // 名称和收藏标记
                HStack(spacing: 6) {
                    if session.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                    
                    Text(session.name)
                        .font(.headline)
                        .lineLimit(1)
                }
                
                // 摘要信息
                Text(session.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                // 最近使用时间
                if let lastUsed = session.formattedLastUsedAt {
                    Text("上次使用: \(lastUsed)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            
            Spacer()
            
            // 快速开始按钮
            Button {
                onStart()
            } label: {
                Image(systemName: "play.circle.fill")
                    .font(.title)
                    .foregroundStyle(.green)
            }
            .buttonStyle(.plain)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel("开始\(session.name)")
            .accessibilityHint("立即开始此练习计划")
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(session.name)，\(session.summary)\(session.isFavorite ? "，已收藏" : "")")
        .accessibilityHint("点击查看详情")
    }
}

// MARK: - Preview

#Preview("Session Card") {
    let block = Block(name: "深蹲", setCount: 3, workDuration: 30, restDuration: 10)
    let session = Session(name: "练腿日", blocks: [block])
    session.isFavorite = true
    session.lastUsedAt = Date().addingTimeInterval(-3600)
    
    return List {
        SessionCard(
            session: session,
            onTap: { print("Tapped") },
            onStart: { print("Started") }
        )
    }
    .listStyle(.plain)
}
