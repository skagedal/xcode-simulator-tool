//
//  Copyright © 2019 Simon Kågedal Reimer. See LICENSE.
//

import Foundation
import Basic
import SPMUtility

struct CommandLineOptions {
    enum SubCommand {
        case noCommand
        case version
        case command(Command)
    }

    struct Error: Swift.Error {
        let underlyingError: Swift.Error
        private let argumentParser: ArgumentParser

        fileprivate init(underlyingError: Swift.Error, argumentParser: ArgumentParser) {
            self.underlyingError = underlyingError
            self.argumentParser = argumentParser
        }

        func printUsage(on stream: OutputByteStream) {
            argumentParser.printUsage(on: stream)
        }
    }
    struct NoCommandError: Swift.Error { }

    private let parser: ArgumentParser
    fileprivate(set) var subCommand: SubCommand
    fileprivate(set) var verbosity: Verbosity

    private static let allCommands: [Command] = [
        ListCommand(),
        InstallCommand(),
        ExportCommand(),
        RemoveCommand()
    ]

    static func parse(commandName: String, arguments: [String]) throws -> CommandLineOptions {
        let parser = ArgumentParser(
            commandName: commandName,
            usage: "[options] subcommand",
            overview: "Manage Xcode simulators",
            seeAlso: nil
        )

        let binder = ArgumentBinder<CommandLineOptions>()
        binder.bind(parser)

        for command in allCommands {
            let subparser = parser.add(
                subparser: command.name,
                overview: command.overview
            )
            command.addOptions(to: subparser)
        }

        var options = CommandLineOptions(parser: parser, subCommand: .noCommand, verbosity: .normal)
        checkresult: do {
            let result = try parser.parse(arguments)
            try binder.fill(parseResult: result, into: &options)

            // In some cases like --version, we already have a subcommand and are thus already done
            guard case SubCommand.noCommand = options.subCommand else {
                break checkresult
            }

            guard
                let subcommandName = result.subparser(parser),
                let command = allCommands.first(where: { $0.name == subcommandName })
            else {
                throw Error(
                    underlyingError: NoCommandError(),
                    argumentParser: parser
                )
            }

            try command.fillParseResult(result)
            options.subCommand = SubCommand.command(command)
        } catch {
            throw Error(underlyingError: error, argumentParser: parser)
        }
        return options
    }

    func printUsage(on stream: OutputByteStream) {
        parser.printUsage(on: stream)
    }
}

extension ArgumentBinder where Options == CommandLineOptions {
    func bind(_ parser: ArgumentParser) {
        bind(
            option: parser.add(
                option: "--version",
                kind: Bool.self,
                usage: "Prints the version and exits"
            ), to: { options, _ in
                options.subCommand = .version
            }
        )

        bind(
            option: parser.add(
                option: "--verbosity",
                kind: Verbosity.self,
                usage: "Verbosity: silent|normal|loud, defaults to normal"
            ), to: { options, verbosity in
                options.verbosity = verbosity
            }
        )

    }
}
