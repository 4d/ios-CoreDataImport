//
//  File.swift
//  
//
//  Created by Eric Marchand on 30/06/2020.
//

import Foundation

import Foundation

import Commandant
import XCGLogger

struct CheckCommand: CommandProtocol {

    typealias Options = CheckOptions
    typealias ClientError = Options.ClientError

    let verb: String = "check"
    var function: String = "Check generated core data model"

    func run(_ options: Options) -> Result<(), ClientError> {
        logger.setup(level: options.level, showLogIdentifier: false, showFunctionName: false, showThreadName: false, showLevel: true, showFileNames: false, showLineNumbers: false, showDate: false, writeToFile: nil, fileLevel: nil)

        if options.coreDataDebug {
            UserDefaults.standard.set(1, forKey: "com.apple.CoreData.SQLDebug")
        } else {
            UserDefaults.standard.removeObject(forKey: "com.apple.CoreData.SQLDebug")
        }

        guard let structurePath = options.structure else {
            logger.error("You must define --structure <structure path>")
            exit(1)
        }
        var structureURL = URL(fileURLWithPath: structurePath)
        let tmpURL = structureURL.appendingPathComponent(structureURL.lastPathComponent).deletingPathExtension()
        var modelName = "Structures"
        if structureURL.pathExtension == "xcdatamodeld" {
            modelName = tmpURL.lastPathComponent
            structureURL = tmpURL.appendingPathExtension("xcdatamodel")
            guard case .directory = fileManager.existence(at: structureURL) else {
                logger.error("structure folder \(structureURL) does not exist")
                exit(2)
            }
        }
        if structureURL.pathExtension == "xcdatamodel" {
            structureURL.appendPathComponent("contents")
        }
        guard case .file = fileManager.existence(at: structureURL) else {
            logger.error("structure folder \(structureURL) does not exist")
            exit(2)
        }

        let outputPath = options.output
        let outputURL = URL(fileURLWithPath: outputPath)
        guard case .directory = fileManager.existence(at: outputURL) else {
            logger.error("output \(outputPath) not exist")
            exit(21)
        }

        let start = DispatchTime.now()
        let generate = Checker()
        generate.check(structureURL: structureURL, outputURL: outputURL, modelName: modelName)

        if logger.isEnabledFor(level: .debug) {
            let nanoTime =  DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds
            let timeInterval = Double(nanoTime) / 1_000_000_000 // Technically could overflow for long running tests
            logger.debug("Time elapsed: \(timeInterval) seconds")
        }
        if generate.hasError {
            logger.warning("Some tables has not been analyzed correctly or global stamps is not available")
            exit(3)
        } else {
            return .success(())
        }
    }

}

struct CheckOptions: OptionsProtocol {
    typealias ClientError = CommandantError<()>

    let structure: String?
    let asset: String?
    let output: String
    let verbosity: Int?
    let quiet: Bool
    let coreDataDebug: Bool

    static func create(_ structure: String?) -> (_ asset: String?) -> (_ output: String) -> (_ verbosity: Int?) -> (_ quiet: Bool) ->  (_ coreDataDebug: Bool) -> CheckOptions {
        return { asset in
            return { output in
                return { verbosity in
                    return { quiet in
                        return { coreDataDebug in
                            self.init(structure: structure, asset: asset, output: output, verbosity: verbosity, quiet: quiet, coreDataDebug: coreDataDebug)
                        }
                    }
                }
            }
        }
    }

    static func evaluate(_ mode: CommandMode) -> Result<CheckCommand.Options, CommandantError<CheckOptions.ClientError>> {
        return create
            <*> mode <| Option(key: "structure", defaultValue: nil, usage: "validate project root directory")
            <*> mode <| Option(key: "asset", defaultValue: nil, usage: "the reporter used to show graph")
            <*> mode <| Option(key: "output", defaultValue: FileManager.default.currentDirectoryPath, usage: "the path to IBGraph's configuration file")
            <*> mode <| Option(key: "verbosity", defaultValue: XCGLogger.Level.info.rawValue, usage: "the level of verbosity (0: verbose, 1: debug, 2: info, .. ), default: 2")
            <*> mode <| Option(key: "quiet", defaultValue: false, usage: "do not log (equalivalent to verbosity=6")
            <*> mode <| Option(key: "coreDataDebug", defaultValue: false, usage: "debug core data request")
    }

    var level: XCGLogger.Level {
        if self.quiet {
            return .none
        } else if let verbosity = self.verbosity, let vLevel = XCGLogger.Level(rawValue: verbosity) {
            return vLevel
        } else {
            return .info
        }
    }

}
