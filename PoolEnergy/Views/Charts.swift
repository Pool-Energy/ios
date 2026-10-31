import SwiftUI
import Charts

struct ChartPoint: Identifiable {
    let id: Date
    let date: Date
    let value: Double
}

struct SeriesChart: View {
    let points: [ChartPoint]
    var format: (Double) -> String = { Fmt.bytes($0) }
    var height: CGFloat = 180

    var body: some View {
        if points.isEmpty {
            EmptyStateView(text: "—")
        } else {
            Chart(points) { point in
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.brand.opacity(0.35), Theme.brand.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(Theme.brand)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let raw = value.as(Double.self) {
                            Text(format(raw))
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.day().month())
                }
            }
            .frame(height: height)
        }
    }
}

extension Array where Element == TimeseriesPoint {
    func chartPoints() -> [ChartPoint] {
        compactMap { point in
            guard let date = point.date else { return nil }
            return ChartPoint(id: date, date: date, value: point.value)
        }
        .sorted { $0.date < $1.date }
    }
}
