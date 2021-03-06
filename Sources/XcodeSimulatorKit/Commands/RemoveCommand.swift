//
//  Copyright © 2019 Simon Kågedal Reimer. See LICENSE.
//

import Foundation
import SPMUtility

class RemoveCommand: Command {
    private struct Options {
        var dryRun: Bool = false
    }
    let name = "remove"
    let overview = "Remove all Certificate Authorities from specified devices"

    private let binder = ArgumentBinder<Options>()
    private var options = Options()

    private let filteringBinder = ArgumentBinder<FilteringOptions>()
    private var filteringOptions = FilteringOptions()

    func addOptions(to parser: ArgumentParser) {
        binder.bind(option: parser.add(
            option: "--dry-run",
            kind: Bool.self,
            usage: "Don't actually remove any CA:s"
        ), to: { options, dryRun in
            options.dryRun = dryRun
        })

        filteringBinder.bind(parser)
    }

    func fillParseResult(_ parseResult: ArgumentParser.Result) throws {
        try binder.fill(parseResult: parseResult, into: &options)
        try filteringBinder.fill(parseResult: parseResult, into: &filteringOptions)
    }

    func run(reporter: Reporter) throws {
        for device in try Simctl.flatListDevices().filter(using: filteringOptions) {
            let trustStore = TrustStore(uuid: device.udid)
            if trustStore.exists {
                try removeCertificates(in: trustStore, deviceName: device.name, dry: options.dryRun)
            }
        }
    }

    private func removeCertificates(in trustStore: TrustStore, deviceName: String, dry: Bool) throws {
        let connection = try trustStore.open()
        for row in try connection.rows() {
            let certificate = try row.validatedCertificate()
            let name = certificate.subjectSummary ?? "<unknown certificate>"
            if dry {
                print("Would remove certificate \(name) from \(deviceName).")
            } else {
                print("Removing certificate \(name) from \(deviceName).")
                try connection.removeCertificate(with: row.sha1)
            }
        }
    }
}
