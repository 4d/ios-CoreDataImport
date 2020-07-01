import Foundation

import Commandant
import XCGLogger

let logger = XCGLogger.default

public class App {

    public init() {}

    public func run() {
        let registry = CommandRegistry<CommandantError<()>>()
        registry.register(GenerateCommand())
        registry.register(DumpCommand())
        registry.register(CheckCommand())
        registry.register(HelpCommand(registry: registry))
        registry.register(VersionCommand())

        registry.main(defaultVerb: GenerateCommand().verb) { (error) in
            logger.error(String.init(describing: error))
        }
    }

}
