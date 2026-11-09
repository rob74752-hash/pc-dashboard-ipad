import SwiftUI
import Charts

struct PerformancePage: View {
    @Environment(Store.self) private var store

    var body: some View {
        GeometryReader { g in
            let wide = g.size.width > 900
            ScrollView {
                VStack(spacing: Theme.gap) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Eyebrow("History")
                            Text("Touch and drag a chart to see earlier values.")
                                .font(.small).foregroundStyle(Theme.text3)
                        }
                        Spacer()
                        RangePicker()
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 4)

                    ThreadHeat()

                    let columns = Array(repeating: GridItem(.flexible(), spacing: Theme.gap), count: wide ? 2 : 1)
                    LazyVGrid(columns: columns, spacing: Theme.gap) {
                        MetricChart(title: "Processor", unit: "%", maxValue: 100,
                                    series: [.init(name: "CPU", key: \.cpu, color: Theme.gold)])
                        MetricChart(title: "Graphics", unit: "%", maxValue: 100,
                                    series: [.init(name: "GPU", key: \.gpu, color: Theme.gold)])
                        MetricChart(title: "Memory", unit: "%", maxValue: 100,
                                    series: [.init(name: "Memory", key: \.mem, color: Theme.gold)])
                        MetricChart(title: "Network", unit: "Mb/s",
                                    series: [.init(name: "Download", key: \.rx, color: Theme.gold),
                                             .init(name: "Upload", key: \.tx, color: Theme.ivory.opacity(0.55))],
                                    convert: { $0 * 8 / 1_000_000 })
                        MetricChart(title: "CPU temperature", unit: store.settings.fahrenheit ? "°F" : "°C",
                                    series: [.init(name: "CPU", key: \.tcpu, color: Theme.gold)],
                                    convert: tempConvert, floor: store.settings.fahrenheit ? 80 : 25)
                        MetricChart(title: "GPU temperature", unit: store.settings.fahrenheit ? "°F" : "°C",
                                    series: [.init(name: "GPU", key: \.tgpu, color: Theme.gold)],
                                    convert: tempConvert, floor: store.settings.fahrenheit ? 80 : 25)
                        MetricChart(title: "Disk", unit: "MB/s",
                                    series: [.init(name: "Read", key: \.rd, color: Theme.gold),
                                             .init(name: "Write", key: \.wr, color: Theme.ivory.opacity(0.55))],
                                    convert: { $0 / 1_048_576 })
                    }
                }
                .padding(16)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var tempConvert: (Double) -> Double {
        let f = store.settings.fahrenheit
        return { f ? $0 * 9 / 5 + 32 : $0 }
    }
}

struct RangePicker: View {
    @Environment(Store.self) private var store
    private let options = [1, 5, 15, 30]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { m in
                let on = store.settings.historyMinutes == m
                Button {
                    store.binding(\.historyMinutes).wrappedValue = m
                } label: {
                    Text(m == 1 ? "1 MIN" : "\(m) MIN")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(on ? Color.black : Theme.text2)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(on ? Theme.gold : Color.clear)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 1))
        .animation(.easeOut(duration: 0.2), value: store.settings.historyMinutes)
    }
}

/// Every CPU thread as a tile that glows brighter gold the busier it is.
struct ThreadHeat: View {
    @Environment(Store.self) private var store

    var body: some View {
        let cores = store.snap?.cpu.cores ?? []
        let perRow = cores.count > 16 ? Int((Double(cores.count) / 2).rounded(.up)) : max(1, cores.count)
        Card(title: "Each thread", trailing: Interpret.shortCPU(store.snap?.cpu.name ?? "")) {
            let rows: [[(Int, Double)]] = stride(from: 0, to: cores.count, by: perRow).map { start in
                (start..<min(cores.count, start + perRow)).map { ($0 - start, cores[$0]) }
            }
            VStack(spacing: 4) {
                ForEach(Array(rows.enumerated()), id: \.offset) { r, row in
                    HStack(spacing: 4) {
                        ForEach(row, id: \.0) { item in
                            let v = item.1
                            let idx = r * perRow + item.0
                            ZStack {
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(Theme.gold.opacity(0.06 + 0.86 * v / 100))
                                VStack(spacing: 2) {
                                    Text("\(Int(v.rounded()))")
                                        .font(.system(size: 15, weight: .semibold).monospacedDigit())
                                        .contentTransition(.numericText())
                                    Text("T\(idx + 1)")
                                        .font(.system(size: 9, weight: .semibold))
                                        .opacity(0.6)
                                }
                                .foregroundStyle(v > 55 ? Color.black : Theme.ivory)
                            }
                            .frame(height: 50)
                        }
                    }
                }
            }
            .animation(.smooth(duration: 0.6), value: cores)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct ChartSeries: Identifiable {
    var id: String { name }
    var name: String
    var key: KeyPath<Sample, Double?>
    var color: Color
}

/// One history chart: title, current value, range, dashed average and a drag-to-inspect cursor.
struct MetricChart: View {
    @Environment(Store.self) private var store
    var title: String
    var unit: String
    var maxValue: Double? = nil
    var series: [ChartSeries]
    var convert: (Double) -> Double = { $0 }
    var floor: Double = 0

    @State private var selected: Date?

    struct Point: Identifiable {
        var id: String { series + String(t.timeIntervalSince1970) }
        var series: String
        var t: Date
        var v: Double
    }

    var body: some View {
        let data = store.history(minutes: store.settings.historyMinutes, maxPoints: 180)
        let points: [Point] = series.flatMap { s in
            data.compactMap { smp in smp[keyPath: s.key].map { Point(series: s.name, t: smp.t, v: convert($0)) } }
        }
        let main = points.filter { $0.series == series[0].name }.map(\.v)
        let avg = main.isEmpty ? nil : main.reduce(0, +) / Double(main.count)
        let lo = main.min()
        let hi = main.max()
        let top = maxValue ?? niceMax(max(points.map(\.v).max() ?? 1, floor + 1))
        let bottom = maxValue == nil ? min(floor, lo ?? 0) : 0
        let current = main.last

        Card(title: title, trailing: lo.flatMap { l in hi.map { "\(fmt(l))–\(fmt($0)) \(unit)" } }) {
            HStack(alignment: .firstTextBaseline) {
                BigNumber(value: current.map { fmt($0) } ?? "--", unit: unit, size: 30)
                Spacer()
                if series.count > 1 {
                    HStack(spacing: 14) {
                        ForEach(series) { s in
                            HStack(spacing: 6) {
                                Capsule().fill(s.color).frame(width: 14, height: 2)
                                Text(s.name).font(.small).foregroundStyle(Theme.text2)
                            }
                        }
                    }
                }
            }
            Chart {
                ForEach(points) { p in
                    LineMark(x: .value("Time", p.t), y: .value(unit, p.v), series: .value("Series", p.series))
                        .foregroundStyle(color(of: p.series))
                        .lineStyle(StrokeStyle(lineWidth: 1.6, lineJoin: .round))
                        .interpolationMethod(.monotone)
                }
                if series.count == 1 {
                    ForEach(points) { p in
                        AreaMark(x: .value("Time", p.t), yStart: .value("Base", bottom), yEnd: .value(unit, p.v))
                            .foregroundStyle(LinearGradient(colors: [Theme.ember.opacity(0.28), Theme.ember.opacity(0)],
                                                            startPoint: .top, endPoint: .bottom))
                            .interpolationMethod(.monotone)
                    }
                }
                if let avg {
                    RuleMark(y: .value("Average", avg))
                        .foregroundStyle(Theme.gold.opacity(0.55))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
                        .annotation(position: .top, alignment: .leading, spacing: 2) {
                            Text("avg \(fmt(avg))")
                                .font(.system(size: 10, weight: .semibold).monospacedDigit())
                                .foregroundStyle(Theme.gold)
                        }
                }
                if let sel = selected, let near = nearest(sel, in: data) {
                    RuleMark(x: .value("Time", near.t))
                        .foregroundStyle(Theme.ivory.opacity(0.35))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                        .annotation(position: .top, alignment: .center, spacing: 4,
                                    overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                            tooltip(near)
                        }
                    ForEach(series) { s in
                        if let v = near[keyPath: s.key] {
                            PointMark(x: .value("Time", near.t), y: .value(unit, convert(v)))
                                .foregroundStyle(s.color)
                                .symbolSize(36)
                        }
                    }
                }
            }
            .chartXSelection(value: $selected)
            .chartYScale(domain: bottom...top)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1)).foregroundStyle(Theme.ivory.opacity(0.06))
                    AxisValueLabel(format: .dateTime.hour().minute())
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.text3)
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1)).foregroundStyle(Theme.ivory.opacity(0.06))
                    AxisValueLabel()
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundStyle(Theme.text3)
                }
            }
            .chartLegend(.hidden)
            .frame(height: 150)
        }
    }

    private func color(of name: String) -> Color {
        series.first { $0.name == name }?.color ?? Theme.gold
    }

    private func nearest(_ date: Date, in data: [Sample]) -> Sample? {
        data.min { abs($0.t.timeIntervalSince(date)) < abs($1.t.timeIntervalSince(date)) }
    }

    private func fmt(_ v: Double) -> String {
        if v >= 100 || maxValue != nil { return String(Int(v.rounded())) }
        if v >= 10 { return String(format: "%.1f", v) }
        return String(format: "%.2f", v)
    }

    private func niceMax(_ v: Double) -> Double {
        let raw = v * 1.15
        let mag = pow(10, Foundation.floor(log10(max(raw, 0.0001))))
        for step in [1.0, 2.0, 2.5, 5.0, 10.0] where step * mag >= raw { return step * mag }
        return raw
    }

    @ViewBuilder private func tooltip(_ s: Sample) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(s.t, format: .dateTime.hour().minute().second())
                .font(.system(size: 10, weight: .semibold).monospacedDigit())
                .foregroundStyle(Theme.text3)
            ForEach(series) { ser in
                if let v = s[keyPath: ser.key] {
                    HStack(spacing: 6) {
                        Circle().fill(ser.color).frame(width: 6, height: 6)
                        Text("\(ser.name) \(fmt(convert(v))) \(unit)")
                            .font(.system(size: 12, weight: .semibold).monospacedDigit())
                            .foregroundStyle(Theme.ivory)
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.black, in: RoundedRectangle(cornerRadius: Theme.radius))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius).strokeBorder(Theme.gold.opacity(0.6), lineWidth: 1))
    }
}
