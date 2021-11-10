//
//  Generator.swift
//  CoreDataImportKit
//
//  Created by Eric Marchand on 26/09/2019.
//

import Foundation

import MomXML
import SWXMLHash
import CoreData

import QMobileAPI
import QMobileDataStore
import QMobileDataSync

import Prephirences

public class Generator {

    var shouldExit: Bool = false
    public var hasError: Bool = false

    public init() {
    }

    public func generate(urls: [URL], structureURL: URL, outputURL: URL, modelName: String, legacy: Bool = false) {
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
        var pref = Prephirences.sharedMutableInstance
        pref?["server.url"] = "localhost" // avoid log

        if legacy {
            pref?["dataSync.newSync"] = false
        }

        CoreDataObjectModel.default = .callback({ () -> (NSManagedObjectModel, String) in
            return (manageObjectModel, modelName)
        })

        let storeURL = outputURL.appendingPathComponent(modelName).appendingPathExtension("sqlite").resolvingSymlinksInPath()
        let storePath = storeURL.path
        if fileManager.fileExists(atPath: storePath) {
            logger.warning("Destination \(storeURL) already exists. Removing it it.")
            do {
                try fileManager.removeItem(at: storeURL)
                try? fileManager.removeItem(at: storeURL.deletingPathExtension().appendingPathExtension("sqlite-shm"))
                try? fileManager.removeItem(at: storeURL.deletingPathExtension().appendingPathExtension("sqlite-wal"))
            } catch {
                logger.error("Cannot remove \(storeURL). Please remove it it. \(error)")
                return
            }
        }

        let dataStore = CoreDataStore(storeType: .sql(outputURL))

        let runLoop: RunLoop = .current
        var storeSize: UInt64 = 0
        logger.info("Loading data store")
        dataStore.load { result in
            storeSize = fileManager.size(atPath: storePath) ?? 0
            logger.debug("Initial store size \(storeSize)")
            switch result {
            case .success:
                logger.info("...data store loaded.")
                //DataSync.instance.loadTable { _ in
                self.perform(dataStore, urls, fileManager)
            // }
            case .failure(let error):
                logger.error("...data store not loaded: \(error)")
            }
            self.shouldExit = true
        }
        logger.info("Waiting for data store...")
        while !shouldExit && (runLoop.run(mode: RunLoop.Mode.default, before: Date(timeIntervalSinceNow: 5))) {
            // do nothing
        }
        // Add sometimes for disk flush? just check file size?
        logger.debug("Wait disk flush...")
        logger.debug("Store size \(fileManager.size(atPath: storePath) ?? 0)")
        var cpt = 0
        var newSize = fileManager.size(atPath: storePath) ?? 0
        while (cpt < 2 && newSize <= storeSize) && (runLoop.run(mode: RunLoop.Mode.default, before: Date(timeIntervalSinceNow: 5))) {
            cpt+=1
            logger.debug("Store size \(fileManager.size(atPath: storePath) ?? 0)")
            newSize = fileManager.size(atPath: storePath) ?? 0
        }
    }

    fileprivate func perform(_ dataStore: DataStore, _ urls: [URL], _ fileManager: FileManager) {
        _ = dataStore.perform(.foreground, wait: true) { context in
            var stamps: [String: TableStampStorage.Stamp] = [:]
            for datasetURL in urls {
                guard case .directory = fileManager.existence(at: datasetURL), datasetURL.pathExtension == "dataset" else {
                    logger.debug("No dataset folder")
                    continue
                }
                let tempURL = datasetURL.appendingPathComponent(datasetURL.lastPathComponent).deletingPathExtension()
                let tableName = tempURL.lastPathComponent

                var dataURL = tempURL.appendingPathExtension("data.json")
                var index = 0
                while (fileManager.existence(at: dataURL) == .file) {
                    guard let json = try? JSON(fileURL: dataURL) else {
                        continue
                    }

                    logger.info("Import \(tableName): \(dataURL) ")
                    guard let builder = DataSyncBuilder.builder(for: tableName, context: context) else {
                        logger.error("Not able to import \(tableName). Not in structure.")
                        self.hasError = true
                        continue
                    }
                    do {
                        let records =  try builder.parseArray(json: json)
                        logger.info("Imported \(records.count) entity for \(tableName)")
                        if logger.isEnabledFor(level: .debug) {

                            if let count = try? context.count(in: builder.tableInfo.name) {
                                if count != records.count {
                                    logger.warning("Found \(count) entity in \(tableName) instead of \(records.count)?")
                                } else {
                                    logger.debug("Found \(count) entity in \(tableName)")
                                }
                            }
                            for destinationTable in Set(builder.tableInfo.relationships.compactMap({ $0.destinationTable?.name })) {
                                logger.warning("RELATED TABLE: Found \(String(describing: try? context.count(in: destinationTable))) entity in \(destinationTable) after \(tableName) import")
                            }
                            // logger.warning("PENDING RECORD: \(PendingRecord.pendingRecords.count)")
                        }
                    } catch {
                        self.hasError = true
                        logger.error("Error when importing \(tableName) \(index): \(error)")
                    }
                    index+=1
                    dataURL = tempURL.appendingPathExtension("\(index).data.json")

                    if let currentStamp = stamps[tableName] {
                        stamps[tableName] = min(currentStamp, json[ImportKey.globalStamp].intValue)
                    } else {
                        stamps[tableName] = json[ImportKey.globalStamp].intValue
                    }
                }
            }

            // read global stamp from embedded files
            if var stampStorage = dataStore.metadata?.stampStorage {
                var globalStamp = 0
                for (_, stamp) in stamps {
                    // stampStorage.set(stamp: stamp, for: table)
                    if (globalStamp == 0) || (stamp != 0 && stamp < globalStamp) { // take the min but not zero (all stamps must be equal or zero, but in case of)
                        globalStamp = stamp
                    }
                }
                stampStorage.globalStamp = globalStamp
                logger.debug("Global stamp \(globalStamp)")
                stampStorage.lastSync = Date()
            }
            let toDeleteRecords: [Record] = context.pendingRecords
            if !toDeleteRecords.isEmpty {
                logger.info("Remove from dump records that are only accessible by links (\(toDeleteRecords.count))")
                context.delete(records: toDeleteRecords)

                if logger.isEnabledFor(level: .debug) {
                    let recordsByTableName = toDeleteRecords.dictionaryBy{ (record: Record) in
                        // return record.tableName // compilation issue, ambigious
                        return record.tableInfo.name
                    }
                    for (tableName, records) in recordsByTableName {
                        logger.debug("\(tableName): \(records.count)")
                        if logger.isEnabledFor(level: .verbose) {
                            logger.verbose("\(records)")
                        }
                    }
                }
            }
            do {
                try context.commit()
            } catch let error as DataStoreError {
                self.hasError = true
                logger.error("Error when saving database \(error.error)")
            }  catch  {
                self.hasError = true
                logger.error("Error when saving database \(error)")
            }
        }
    }
}

extension Array {
    /// Create a dictionary from this array.
    ///
    /// - parameter key: A closure to get hashing key from array values.
    ///
    /// - returns: the dictionary
    func dictionaryBy<T: Hashable>(key: (Element) -> T) -> [T: [Element]] {
        var result: [T: [Element]] = [:]
        self.forEach {
            let keyValue = key($0)
            if result[keyValue] == nil {
                result[keyValue] = []
            }
            result[keyValue]?.append($0)
        }
        return result
    }
}
