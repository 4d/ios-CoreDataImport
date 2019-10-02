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

class Generator {

    var shouldExit: Bool = false
    var hasError: Bool = false

    func generate(urls: [URL], structureURL: URL, outputURL: URL, modelName: String) {
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

        CoreDataObjectModel.default = .callback({ () -> (NSManagedObjectModel, String) in
            return (manageObjectModel, modelName)
        })

        let storeURL = outputURL.appendingPathComponent(modelName).appendingPathExtension("sqlite").resolvingSymlinksInPath()
        if fileManager.fileExists(atPath: storeURL.path) {
            logger.error("Destination \(storeURL) already exists. Remove it.")
            try? fileManager.removeItem(at: storeURL)
        }

        let dataStore = CoreDataStore(storeType: .sql(outputURL))

        let runLoop: RunLoop = .current
        logger.info("Loading data store")
        dataStore.load { result in
            switch result {
            case .success:
                logger.info("...data store loaded.")
                self.perform(dataStore, urls, fileManager)
            case .failure(let error):
                logger.error("...data store not loaded: \(error)")
            }
            self.shouldExit = true
        }
        logger.info("Waiting for data store...")
        while !shouldExit && (runLoop.run(mode: RunLoop.Mode.default, before: Date(timeIntervalSinceNow: 5))) {
            // do nothing
        }
        // Add sometimes for disk flush?
        // TODO: find a better way to wait for disk flush
        logger.debug("Wait disk flush...")
        var cpt = 0
        while cpt < 2 && (runLoop.run(mode: RunLoop.Mode.default, before: Date(timeIntervalSinceNow: 5))) {
            cpt+=1
        }
    }

    fileprivate func perform(_ dataStore: DataStore, _ urls: [URL], _ fileManager: FileManager) {
        _ = dataStore.perform(.foreground, wait: true) { context in
            var stamps: [String: TableStampStorage.Stamp] = [:]
            for datasetURL in urls {
                guard case .directory = fileManager.existence(at: datasetURL), datasetURL.pathExtension == "dataset" else {
                    continue
                }
                let tempURL = datasetURL.appendingPathComponent(datasetURL.lastPathComponent).deletingPathExtension()
                let tableName = tempURL.lastPathComponent
                let dataURL = tempURL.appendingPathExtension("data.json")
                guard case .file = fileManager.existence(at: dataURL), let json = try? JSON(fileURL: dataURL) else {
                    continue
                }

                logger.info("Import \(tableName): \(dataURL) ")
                guard let builder = DataSyncBuilder(tableName: tableName, context: context) else {
                    logger.error("Not able to import \(tableName). Not in structure.")
                    self.hasError = true
                    continue
                }
                do {
                    let records =  try builder.parseArray(json: json)
                    logger.info("Imported \(records.count) entity for \(tableName)")
                    if logger.isEnabledFor(level: .debug), let count = try? context.count(in: tableName) {
                        if count != records.count {
                            logger.warning("Found \(count) entity in \(tableName)" )
                        } else {
                            logger.debug("Found \(count) entity in \(tableName)" )
                        }
                    }
                } catch {
                    self.hasError = true
                    logger.error("Error when importing \(tableName): \(error)")
                }

                stamps[tableName] = json[ImportKey.globalStamp].intValue
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
