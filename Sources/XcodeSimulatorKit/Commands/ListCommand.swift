//
//  Copyright © 2019 Simon Kågedal Reimer. See LICENSE.
//

import Foundation
import SPMUtility

class ListCommand: Command {
    let name = "list"
    let overview = "List available certificates in Xcode Simulators"

    private let binder = ArgumentBinder<ListCommand>()
    private var filteringOptions = FilteringOptions()
    private let filteringBinder = ArgumentBinder<FilteringOptions>()

    func addOptions(to parser: ArgumentParser) {
        filteringBinder.bind(parser)
    }

    func fillParseResult(_ parseResult: ArgumentParser.Result) throws {
        try filteringBinder.fill(parseResult: parseResult, into: &filteringOptions)
    }

    func run(reporter: Reporter) throws {
        let allDevices = try Simctl.listDevices()
        for (runtime, devices) in allDevices.devices {
            let filteredDevices = devices.filter(using: filteringOptions)
            guard !filteredDevices.isEmpty else {
                continue
            }
            print("\(runtime):")
            for device in filteredDevices {
                print(" - \(device.name)")
                let trustStore = TrustStore(uuid: device.udid)
                if trustStore.exists {
                    try listCertificates(in: trustStore)
                }
            }
        }
    }

    private func listCertificates(in trustStore: TrustStore) throws {
        let store = try trustStore.open()
        guard store.isValid() else {
            return print("   Invalid trust store at \(trustStore.path)")
        }

        var didPrintHeader = false
        for row in try store.rows() {
            if !didPrintHeader {
                print("   Certificates:")
                didPrintHeader = true
            }
            do {
                let certificate = try row.validatedCertificate()
                print("    - \(certificate.subjectSummary ?? "<unknown certificate>")")
            } catch {
                print("    - Invalid row: \(error.localizedDescription)")
            }
        }
    }
}
