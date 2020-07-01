//
//  Dumper.swift
//  CoreDataImportKit
//
//  Created by Eric Marchand on 29/06/2020.
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

public class Dumper {

    var shouldExit: Bool = false
    public var hasError: Bool = false

    public init() {
    }

    public func dump(serverURL: URL, structureURL: URL, outputURL: URL, modelName: String, token: String, filter: String?) {


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

        var pref = Prephirences.sharedMutableInstance
        pref?["server.url"] = serverURL.absoluteString


        let api = APIManager.instance
        api.authToken = AuthToken(id: "token", statusText: "command line", token: token)

        let runLoop: RunLoop = .current
        logger.info("Loading data store")

        let dataStore = CoreDataStore(storeType: .inMemory)
        dataStore.load { result in

            _ = dataStore.perform(.foreground, wait: true) { context in
                let tableInfos = context.tablesInfo
                let count = tableInfos.count
                var cpt = 0
                for tableInfo in tableInfos {
                    let table: Table = tableInfo.api

                    let target = api.base.records(from: table, attributes: self.getAttributes(table, tableInfo))
                    let completion: APIManager.Completion = { [unowned self] result in
                        switch result {
                        case .success(let response):
                            let data = response.data
                            let dataset = outputURL.appendingPathComponent(table.name).appendingPathExtension("dataset")
                            try? fileManager.createDirectory(at: dataset, withIntermediateDirectories: true)
                            let fileName = table.name+".data.json"
                            let fileURL = dataset.appendingPathComponent(fileName)
                            do {
                                if fileManager.fileExists(atPath: fileURL.absoluteString) {
                                    try fileManager.removeItem(at: fileURL)
                                }
                                try data.write(to: fileURL)
                                logger.info("Table \(table.name) dumped")

                                let contentJSON = "{\"data\":[{\"filename\":\""+fileName+"\",\"idiom\":\"universal\",\"universal-type-identifier\":\"public.json\"}],\"info\":{\"author\":\"xcode\",\"version\":1}}"
                                try? contentJSON.data(using: .utf8)?.write(to: dataset.appendingPathComponent("Contents.json"))

                                cpt += 1
                                if cpt >= count {
                                    self.shouldExit = true
                                }
                            } catch {
                                logger.error("Failed to write to file for table \(table.name): \(error)")
                            }
                        case .failure(let error):
                            logger.error("\(error)")
                            if let restError = error.restErrors {
                                logger.error("\(restError)")
                            }
                            self.shouldExit = true
                        }
                    }
                    self.configureRecordsRequest(target, tableInfo, table, filter)
                    _ = api.request(target, /*queue: queue, progress: progress, */completion: completion)
                }
            }
        }
        logger.info("Waiting for request...")
        while !shouldExit && (runLoop.run(mode: RunLoop.Mode.default, before: Date(timeIntervalSinceNow: 5))) {
            // do nothing
        }
    }

    /// Configure the record request
    func configureRecordsRequest(_ request: RecordsRequest, _ tableInfo: DataStoreTableInfo, _ table: Table, _ filter: String?) {
        /// Defined limit
        request.limit(1000000 /*Prephirences.DataSync.Request.Page.limit*/)

        // If a filter is defined by table in data store, use it
        if let tableFilter = tableInfo.filter {

            if let filter = filter {
                request.filter("(\(tableFilter)) AND \(filter)")
            } else {
                request.filter(tableFilter)
            }


            /* /// Get user info to filter data
             if var params = APIManager.instance.authToken?.userInfo {
             for (key, value) in params {
             if let date = parseDate(from: value), date.isUTCStartOfDay {
             params[key] = "'\(DateFormatter.simpleDate.string(from: date))'" // format for 4d
             // APIManager.instance.authToken?.userInfo = params
             }
             }
             request.params(params)
             // target.params([params])
             logger.debug("Filter query params \(params) for \(table.name) with filter \(filter)")
             }*/
        } else {
            if let filter = filter {
                request.filter(filter)
            }
        }

    }

    /// For one table, get list of attribute to use in records request.
    func getAttributes(_ table: Table, _ tableInfo: DataStoreTableInfo) -> [String] {
        /* guard !Prephirences.DataSync.noAttributeFilter else { return []  }*/
        var attributes: [String] = []
        /* if false /*Prephirences.DataSync.expandAttribute */{
         attributes = table.attributes.filter { !$0.1.type.isRelative }.map { $0.0 }
         } else {*/
        //let fieldInfoByOriginalName = tableInfo.fields.dictionary { $0.originalName }
        attributes = table.attributes.compactMap { (name, attribute) in
            if let relationType = attribute.relativeType {
                if relationType.isToMany {
                    // TODO Check if not a slave table destination
                    return nil // let many to 1 relation make the job
                }
                else if let expand = relationType.expand {
                    let expands = expand.split(separator: ",")
                    return expands.map { "\(name).\($0)"}.joined(separator: ",")
                }
                return nil
            } else {
                if false /*Prephirences.DataSync.allowMissingField*/ {
                    /*if let fieldInfo = fieldInfoByOriginalName?[name], fieldInfo.isMissingRemoteField {  // allow to reload event if missing attributes
                     return nil
                     }*/
                }
                return name
            }
        }
        /*   }*/
        return attributes
    }


}
