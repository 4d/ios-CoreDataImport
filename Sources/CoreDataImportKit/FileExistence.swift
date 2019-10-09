//
//  FileExistence.swift
//  Alamofire
//
//  Created by Eric Marchand on 24/09/2019.
//

import Foundation

public enum FileExistence: Equatable {
    case none
    case file
    case directory
}

public func ==(lhs: FileExistence, rhs: FileExistence) -> Bool {

    switch (lhs, rhs) {
    case (.none, .none),
         (.file, .file),
         (.directory, .directory):
        return true

    default: return false
    }
}

extension FileManager {
    public func existence(at url: URL) -> FileExistence {

        var isDirectory: ObjCBool = false
        let exists = self.fileExists(atPath: url.path, isDirectory: &isDirectory)

        switch (exists, isDirectory.boolValue) {
        case (false, _): return .none
        case (true, false): return .file
        case (true, true): return .directory
        }
    }
}

extension FileManager {

    public func size(atPath path: String) -> UInt64? {
        if let attributes: [FileAttributeKey: Any] = try? self.attributesOfItem(atPath: path),
            let value = attributes[FileAttributeKey.size] as? NSNumber {
            return value.uint64Value
        }
        return nil
    }

}
