#if os(macOS)
    import os.log
    import OSLog
    import SwiftUI
    import Observation

    // swiftlint:disable force_try

    struct ConsoleLogView: View {
        @Observable
        private class Model {
            var entries: [OSLogEntryLog] = [] // NOTE: This grows forever

            private let logStore: OSLogStore

            init() throws {
                logStore = try OSLogStore(scope: .currentProcessIdentifier)
            }

            @MainActor
            func start() async {
                let oneHourAgo = logStore.position(date: Date().addingTimeInterval(-1 * 5))
                let newEntries = try! logStore.getEntries(at: oneHourAgo).compactMap { $0 as? OSLogEntryLog }

                await MainActor.run {
                    self.entries.append(contentsOf: newEntries)
                }
            }
        }

        private var model = try! Model()

        @State
        private var selection: OSLogEntryLog.ID?

        @State
        private var order: [KeyPathComparator<OSLogEntryLog>] = [
            .init(\.date, order: SortOrder.forward),
        ]

        private var entries: [OSLogEntryLog] {
            model.entries.sorted(using: order)
        }

        var body: some View {
            VStack {
                Table(selection: $selection, sortOrder: $order) {
                    TableColumn("Date", value: \.date) { value in
                        Text("\(value.date, format: .dateTime)")
                    }
                    TableColumn("Process", value: \.process)
                    TableColumn("Sender", value: \.sender)
                    TableColumn("Subsystem", value: \.subsystem)
                    TableColumn("Category", value: \.category)
                    TableColumn("Message", value: \.composedMessage)
                }
            rows: {
                    ForEach(entries) {
                        TableRow($0)
                    }
                }
                VStack {
                    if let entry = entries.first(where: { ObjectIdentifier($0) == selection }) {
                        LazyVGrid(columns: [.init(), .init()]) {
                            Group {
                                Text("Level")
                                Text(verbatim: "\(entry.level)")
                                Text("Date")
                                Text(verbatim: "\(entry.date)")
                            }
                            Group {
                                Text("Process")
                                Text(verbatim: "\(entry.process)")
                                Text("Process Identifier")
                                Text(verbatim: "\(entry.processIdentifier)")
                                Text("composedMessage")
                                Text(verbatim: "\(entry.composedMessage)")
                                Text("storeCategory")
                                Text(verbatim: "\(entry.storeCategory)")
                                Text("activityIdentifier")
                                Text(verbatim: "\(entry.activityIdentifier)")
                            }
                            Group {
                                Text("sender")
                                Text(verbatim: "\(entry.sender)")
                                Text("threadIdentifier")
                                Text(verbatim: "\(entry.threadIdentifier)")
                                Text("category")
                                Text(verbatim: "\(entry.category)")
                            }
                            Group {
                                Text("components")
                                Text(verbatim: "\(entry.components)")
                                Text("formatString")
                                Text(verbatim: "\(entry.formatString)")
                                Text("subsystem")
                                Text(verbatim: "\(entry.subsystem)")
                            }
                        }
                    }
                }
            }
            .task {
                await model.start()
            }
        }
    }

    extension OSLogEntry: Identifiable {
    }

#endif
