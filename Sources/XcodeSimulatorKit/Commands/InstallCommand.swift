//
//  Copyright © 2019 Simon Kågedal Reimer. See LICENSE.
//

import Foundation
import SPMUtility

class InstallCommand: Command {
    struct Options {
        var path: String?
        var dryRun: Bool = false
    }
    let name = "install"
    let overview = "Install a Certificate Authority"

    private let binder = ArgumentBinder<Options>()
    private var options = Options()

    private let filteringBinder = ArgumentBinder<FilteringOptions>()
    private var filteringOptions = FilteringOptions()

    func addOptions(to parser: ArgumentParser) {
        binder.bind(option: parser.add(
            option: "--dry-run",
            kind: Bool.self,
            usage: "Don't actually install any CA"
            ), to: { options, dryRun in
            options.dryRun = dryRun
        })

        binder.bind(positional: parser.add(
            positional: "path",
            kind: String.self,
            usage: "Path for the certificate to install"
        ), to: { options, path in
            options.path = path
        })

        filteringBinder.bind(parser)
    }

    func fillParseResult(_ parseResult: ArgumentParser.Result) throws {
        try binder.fill(parseResult: parseResult, into: &options)
        try filteringBinder.fill(parseResult: parseResult, into: &filteringOptions)
    }

    func run(reporter: Reporter) throws {
        let runner = InstallCommandRunner(
            options: options,
            filteringOptions: filteringOptions,
            reporter: reporter
        )
        try runner.run()
    }
}
