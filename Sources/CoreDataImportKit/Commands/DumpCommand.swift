//
//  DumpCommand.swift
//  CoreDataImportKit
//
//  Created by Eric Marchand on 29/06/2020.
//

import Foundation

import Commandant
import XCGLogger

struct DumpCommand: CommandProtocol {

    typealias Options = DumpOptions
    typealias ClientError = Options.ClientError

    let verb: String = "dump"
    var function: String = "dump asset"

    func run(_ options: Options) -> Result<(), ClientError> {
        logger.setup(level: options.level, showLogIdentifier: false, showFunctionName: false, showThreadName: false, showLevel: true, showFileNames: false, showLineNumbers: false, showDate: false, writeToFile: nil, fileLevel: nil)

        guard let assetPath = options.asset else {
            logger.error("You must define --asset <asset path>")
            exit(1)
        }
        let assetURL = URL(fileURLWithPath: assetPath)
        guard case .directory = fileManager.existence(at: assetURL) else {
            logger.error("asset folder \(assetPath) does not exist")
            exit(2)
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

        guard let serverURL = URL(string: options.serverURL) else {
            logger.error("You must define a correct server url \(options.serverURL)")
            exit(1)
        }

        guard let token = options.token else {
            logger.error("you must define token")
            exit(2)
        }

        let start = DispatchTime.now()
        let dumper = Dumper()
        dumper.dump(serverURL: serverURL, structureURL: structureURL, outputURL: assetURL.appendingPathComponent("Data"), modelName: modelName, token: token, filter: options.filter)
        let nanoTime = DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds
        let timeInterval = Double(nanoTime) / 1_000_000_000 // Technically could overflow for long running tests
        logger.info("Time elapsed: \(timeInterval) seconds")

        logger.info("Dumped in \(assetURL.resolvingSymlinksInPath().absoluteString)")
        if dumper.hasError {
            logger.warning("Some tables has not been imported")
            exit(3)
        } else {
            return .success(())
        }
    }

}

struct DumpOptions: OptionsProtocol {
    typealias ClientError = CommandantError<()>

    let structure: String?
    let asset: String?
    let serverURL: String
    let verbosity: Int?
    let quiet: Bool
    let token: String?
    let filter: String?

    static func create(_ structure: String?) -> (_ asset: String?) -> (_ serverURL: String) -> (_ verbosity: Int?) -> (_ quiet: Bool) ->  (_ token: String?) -> (_ filter: String?) -> DumpOptions {
        return { asset in
            return { serverURL in
                return { verbosity in
                    return { quiet in
                        return { token in
                            return { filter in
                                self.init(structure: structure, asset: asset, serverURL: serverURL, verbosity: verbosity, quiet: quiet, token: token, filter: filter)
                            }
                        }
                    }
                }
            }
        }
    }

    static func evaluate(_ mode: CommandMode) -> Result<DumpCommand.Options, CommandantError<GenerateOptions.ClientError>> {
        return create
            <*> mode <| Option(key: "structure", defaultValue: nil, usage: "the core data structure path")
            <*> mode <| Option(key: "asset", defaultValue: nil, usage: "the asset path")
            <*> mode <| Option(key: "server", defaultValue: "http://localhost", usage: "server URL")
            <*> mode <| Option(key: "verbosity", defaultValue: XCGLogger.Level.info.rawValue, usage: "the level of verbosity (0: verbose, 1: debug, 2: info, .. ), default: 2")
            <*> mode <| Option(key: "quiet", defaultValue: false, usage: "do not log (equalivalent to verbosity=6")
            <*> mode <| Option(key: "token", defaultValue: nil, usage: "token to auth")
            <*> mode <| Option(key: "filter", defaultValue: nil, usage: "additional filter")
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
