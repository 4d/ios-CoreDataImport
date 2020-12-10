//
//  File.swift
//  
//
//  Created by Eric Marchand on 30/06/2020.
//

import Foundation

import MomXML
import SWXMLHash
import CoreData
import Moya

import QMobileAPI
import QMobileDataStore
import QMobileDataSync

import Prephirences

public class Checker {

    public var hasError: Bool = false

    public init() {
    }

    public func check(structureURL: URL, outputURL: URL, modelName: String) {
        guard let data = try? Data(contentsOf: structureURL) else {
            logger.error("cannot read \(structureURL)")
            exit(1)
        }
        MomXML.orphanCallback = { xml, expected in
            logger.warning("cannot decode \(xml). Expecting \(expected)")
        }
        let mom = MomXML(xml: SWXMLHash.parse(data))
        guard let manageObjectModel = mom?.coreData else {
            logger.error("cannot convert to core data model \(structureURL)")
            exit(1)
        }
        CoreDataObjectModel.default = .callback({ () -> (NSManagedObjectModel, String) in
            return (manageObjectModel, modelName)
        })

        let dataStore = CoreDataStore(storeType: .sql(outputURL))
        dataStore.load { result in
            _ = dataStore.perform(.foreground, wait: true) { context in
                let tableInfos = context.tablesInfo

                var tableStatss: [TableStats] = []
                for tableInfo in tableInfos {
                    let request = context.fetchRequest(tableName: tableInfo.name)
                    let count = (try? context.count(for: request)) ?? -1
                    var tableStats = TableStats(name: tableInfo.name, count: count)

                    let records = (try? context.fetch(request)) ?? []

                    for (relationName, relationInfo) in tableInfo.relationshipsByName {
                        tableStats.relations[relationName]=0
                        for record in records {
                            if let relationData = record[relationName] {
                                if relationInfo.isToMany {
                                    tableStats.relations[relationName]=tableStats.relations[relationName]!+(relationData as! NSMutableSet).count
                                } else {
                                    tableStats.relations[relationName]=tableStats.relations[relationName]!+1
                                }
                            }
                        }
                    }
                    tableStatss.append(tableStats)
                }
                let globalStamp = (dataStore.metadata?.globalStamp) ?? -1
                let stats = Stats(globalStamp: globalStamp, tables: tableStatss)

                self.hasError = stats.hasError
                // if json encode and print
                // else normal print mode
                logger.info("Entity count:")
                for table in stats.tables {
                    logger.info("  \(table.name): \(table.count)")
                    logger.info("  - relation: \(table.relations)")
                }
                logger.info("GlobalStamp: \(stats.globalStamp), Table count: \(stats.tables.count)")
            }
        }
    }

} 

struct Stats: Codable {
    var globalStamp: Int
    var tables: [TableStats]

    var hasError: Bool {
        return globalStamp < 0 || self.tables.reduce(false, { $0 || $1.hasError})
    }
}
struct TableStats: Codable {
    var name: String
    var count: Int
    var relations: [String: Int] = [:]
    var hasError: Bool {
        return count < 0
    }
}
