import SwiftUI

struct DateDetailView: View {
    let info: ChineseCalendarInfo
    
    private var secondRowItems: [(text: String, type: ItemType)] {
        var items: [(String, ItemType)] = []
        if let holiday = info.holiday, !holiday.isEmpty {
            items.append((holiday, .holiday))
        }
        if let jieQi = info.jieQi, !jieQi.isEmpty {
            items.append((jieQi, .jieQi))
        }
        let ganZhiText = [info.ganZhiYear, info.ganZhiMonth, info.ganZhiDay]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        if !ganZhiText.isEmpty {
            items.append((ganZhiText, .ganZhi))
        }
        
        if let nineDay = info.nineDayDetail {
            items.append((nineDay, .nineDay))
        }
        return items
    }
    
    private enum ItemType {
        case holiday, jieQi, ganZhi, nineDay
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text(info.weekdayText)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                
                Text(info.lunarFullText)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
            }
            
            if !secondRowItems.isEmpty {
                HStack(spacing: 0) {
                    ForEach(Array(secondRowItems.enumerated()), id: \.offset) { index, item in
                        if index > 0 {
                            Text(" | ")
                                .font(.system(size: 13, design: .rounded))
                                .foregroundStyle(.secondary.opacity(0.5))
                        }
                        Text(item.text)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(colorForType(item.type))
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }
    
    /// 按类型返回颜色：干支固定灰色，其余保留语义色
    private func colorForType(_ type: ItemType) -> Color {
        switch type {
        case .holiday: return .red
        case .jieQi:   return .green
        case .ganZhi:  return .secondary
        case .nineDay: return .blue
        }
    }
}
