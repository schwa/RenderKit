import Foundation
import SwiftUI
import Observation
import Everything
import Charts

@Observable
class Counters {
    static let shared = Counters()

    struct Record: Identifiable {
        var id: String
        var count: Int = 0
        var first: TimeInterval
        var last: TimeInterval
        var meanInterval: Double = 0
        var movingAverageInterval = ExponentialMovingAverageIrregular()

        var buckets: [(Range<TimeInterval>,Int)] = []
    }

    var records: [String: Record] = [:]


    func increment(counter key: String) {
        let now = Date.now.timeIntervalSinceReferenceDate
        Task {
            MainActor.runTask {
                if var record = self.records[key] {
                    record.count += 1
                    let last = record.last
                    record.last = now
                    record.meanInterval = (record.last - record.first) / Double(record.count)
                    record.movingAverageInterval.update(time: now - record.first, value: now - last)
                    if var bucket = record.buckets.last, bucket.0.contains(now) {
                        bucket.1 += 1
                        record.buckets = record.buckets.dropLast() + [bucket]
                    }
                    else {
                        let bucket = (floor(now)..<ceil(now), 1)
                        record.buckets.append(bucket)
                    }
                    if record.buckets.count > 10 {
                        record.buckets = Array(record.buckets.dropFirst(record.buckets.count - 10))
                    }
                    self.records[key] = record
                }
                else {
                    self.records[key] = Record(id: key, first: now, last: now)
                }
            }
        }
    }
}

struct CountersView: View {

    @Bindable
    var counters = Counters.shared

    @State
    var selection: Set<String> = []


    var body: some View {
        let records = Array(counters.records.values).sorted(by: \.first)
        VStack {
            Table(records, selection: $selection) {
                TableColumn("Counter") { record in
                    Text(record.id)
                }
                .width(min: 50, ideal: 50)
                TableColumn("Count") { record in
                    Text("\(record.count, format: .number)")
                        .monospacedDigit()
                }
                .width(min: 50, ideal: 50)
                TableColumn("Frequency (Raw)") { record in
                    let interval = record.meanInterval
                    let frequency = interval == 0 ? 0 : 1 / interval
                    Text("\(frequency, format: .number.precision(.fractionLength(2)))")
                        .monospacedDigit()
                }
                .width(min: 50, ideal: 50)
                TableColumn("Moving Average") { record in
                    let interval = record.movingAverageInterval.exponentialMovingAverage
                    let frequency = interval == 0 ? 0 : 1 / interval
                    Text("\(frequency, format: .number.precision(.fractionLength(2)))")
                        .monospacedDigit()
                }
                .width(min: 50, ideal: 50)
            }
            .controlSize(.small)

            if !selection.isEmpty {
                TimelineView(.animation(minimumInterval: 0.5)) { timeline in
                    let records = Array(Counters.shared.records.values)

                    let blobs = records.flatMap { record in
                        record.buckets.dropLast().map { bucket in
                            (record.id, Date(timeIntervalSinceReferenceDate:bucket.0.lowerBound), bucket.1 )
                        }
                    }
                    Chart(blobs, id: \.0) {
                        LineMark(
                            x: .value("Date", $0.1),
                            y: .value("Coun", $0.2)
                        )
                        .foregroundStyle(by: .value("Counter", $0.0))
                    }
                }
            }
        }
    }
}
