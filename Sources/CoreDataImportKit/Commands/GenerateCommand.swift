//
//  GenerateCommand.swift 
//
//  Created by Eric Marchand on 25/09/2019.
//

import Foundation

import Commandant
import XCGLogger

let fileManager = FileManager.default

struct GenerateCommand: CommandProtocol {

    typealias Options = GenerateOptions
    typealias ClientError = Options.ClientError

    let verb: String = "generate"
    var function: String = "Generate core data model (default command)"

    func run(_ options: Options) -> Result<(), ClientError> {
        logger.setup(level: options.level, showLogIdentifier: false, showFunctionName: false, showThreadName: false, showLevel: true, showFileNames: false, showLineNumbers: false, showDate: false, writeToFile: nil, fileLevel: nil)

        if options.coreDataDebug {
            UserDefaults.standard.set(1, forKey: "com.apple.CoreData.SQLDebug")
        }

        guard let assetPath = options.asset else {
            logger.error("You must define --asset <asset path>")
            exit(1)
        }
        let assetURL = URL(fileURLWithPath: assetPath)
        guard case .directory = fileManager.existence(at: assetURL) else {
            logger.error("asset folder \(assetPath) does not exist")
            exit(2)
        }
        let dataURL = assetURL.appendingPathComponent("Data")
        guard case .directory = fileManager.existence(at: dataURL) else {
            logger.error("\(dataURL) not exist")
            exit(21)
        }

        guard let urls = try? fileManager.contentsOfDirectory(at: dataURL, includingPropertiesForKeys: nil, options: []) else {
            logger.error("Cannot read content of \(dataURL) ")
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

        let outputPath = options.output
        let outputURL = URL(fileURLWithPath: outputPath)
        guard case .directory = fileManager.existence(at: outputURL) else {
            logger.error("output \(outputPath) not exist")
            exit(21)
        }

        let start = DispatchTime.now()
        let generate = Generator()
        generate.generate(urls: urls, structureURL: structureURL, outputURL: outputURL, modelName: modelName)
        let nanoTime =  DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds
        let timeInterval = Double(nanoTime) / 1_000_000_000 // Technically could overflow for long running tests
        logger.info("Time elapsed: \(timeInterval) seconds")

        logger.info("Output generated in \(outputURL.resolvingSymlinksInPath().absoluteString)")
        if generate.hasError {
            logger.warning("Some tables has not been imported")
            exit(3)
        } else {
            return .success(())
        }
    }

}

struct GenerateOptions: OptionsProtocol {
    typealias ClientError = CommandantError<()>

    let structure: String?
    let asset: String?
    let output: String
    let verbosity: Int?
    let quiet: Bool
    let coreDataDebug: Bool

    static func create(_ structure: String?) -> (_ asset: String?) -> (_ output: String) -> (_ verbosity: Int?) -> (_ quiet: Bool) ->  (_ coreDataDebug: Bool) -> GenerateOptions {
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

    static func evaluate(_ mode: CommandMode) -> Result<GenerateCommand.Options, CommandantError<GenerateOptions.ClientError>> {
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
