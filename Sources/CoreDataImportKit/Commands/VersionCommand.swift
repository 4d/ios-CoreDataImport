//
//  VersionCommand.swift
//  Alamofire
//
//  Created by Eric Marchand on 25/09/2019.
//

import Foundation

import Commandant

struct VersionCommand: CommandProtocol {
    let verb = "version"
    let function = "Display the current version of IBLinter"

    func run(_ options: NoOptions<CommandantError<()>>) -> Result<(), CommandantError<()>> {
        logger.info(Version.current.value)
        return .success(())
    }
}

public struct Version {
    public let value: String

    public static let current = Version(value: "0.1.0")
}
