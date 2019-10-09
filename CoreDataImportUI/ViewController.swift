//
//  ViewController.swift
//  CoreDataImportUI
//
//  Created by Eric Marchand on 09/10/2019.
//

import Cocoa
import CoreDataImportKit
import XCGLogger
import Prephirences

let logger = XCGLogger()

class ViewController: NSViewController {

    @IBOutlet weak var structureTextField: NSTextField!
    @IBOutlet weak var dataTextField: NSTextField!

    @MutablePreference(key: "structure")
    var structurePath: String?

    @MutablePreference(key: "data")
    var dataPath: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        let defaults = UserDefaults.standard
        Prephirences.sharedInstance = defaults

        // defaults.set(1, forKey: "com.apple.CoreData.SQLDebug")

        // Do any additional setup after loading the view.

        if let path = structurePath {
            structureTextField.stringValue = path
        }
        if let path = dataPath {
            dataTextField.stringValue = path
        }
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    @IBAction func structureSelect(_ sender: Any) {
        let dialog = NSOpenPanel()

        dialog.title                   = "Choose a structure file"
        dialog.showsResizeIndicator    = true
        dialog.showsHiddenFiles        = false
        dialog.canChooseDirectories    = true
        dialog.canCreateDirectories    = false
        dialog.allowsMultipleSelection = false
        //dialog.allowedFileTypes        = ["xcdatamodeld"]

        if (dialog.runModal() == NSApplication.ModalResponse.OK) {
            if let result = dialog.url {
                let path = result.path
                structureTextField.stringValue = path
                self.structurePath = path
            }
        } else {
            // User clicked on "Cancel"
            return
        }
    }

    @IBAction func assetSelect(_ sender: Any) {
        let dialog = NSOpenPanel()
        dialog.title                   = "Choose a asset folder"
        dialog.showsResizeIndicator    = true
        dialog.showsHiddenFiles        = false
        dialog.canChooseDirectories    = true
        dialog.canCreateDirectories    = false
        dialog.allowsMultipleSelection = false
        //dialog.allowedFileTypes        = ["xcassets"]

        if (dialog.runModal() == NSApplication.ModalResponse.OK) {
            if let result = dialog.url {
                let path = result.path
                dataTextField.stringValue = path
                self.dataPath = path
            }
        } else {
            // User clicked on "Cancel"
            return
        }
    }

    var fileManager: FileManager {
        return .default
    }

    @IBAction func quit(_ sender: Any) {
        NSApplication.shared.terminate(sender)
    }

    @IBAction func generate(_ sender: Any) {
        let assetPath = dataTextField.stringValue
        let assetURL = URL(fileURLWithPath: assetPath)
        guard case .directory = fileManager.existence(at: assetURL) else {
            logger.error("asset folder \(assetPath) does not exist")
            alert("asset folder \(assetPath) does not exist")
            return
        }
        let dataURL = assetURL.appendingPathComponent("Data")
        guard case .directory = fileManager.existence(at: dataURL) else {
            logger.error("\(dataURL) not exist")
            alert("\(dataURL) not exist")
            return
        }

        guard let urls = try? fileManager.contentsOfDirectory(at: dataURL, includingPropertiesForKeys: nil, options: []) else {
            logger.error("Cannot read content of \(dataURL) ")
            return
        }

        var structureURL = URL(fileURLWithPath: structureTextField.stringValue)
        let tmpURL = structureURL.appendingPathComponent(structureURL.lastPathComponent).deletingPathExtension()
        var modelName = "Structures"
        if structureURL.pathExtension == "xcdatamodeld" {
            modelName = tmpURL.lastPathComponent
            structureURL = tmpURL.appendingPathExtension("xcdatamodel")
            guard case .directory = fileManager.existence(at: structureURL) else {
                logger.error("structure folder \(structureURL) does not exist")
                alert("structure not exist")
                return
            }
        }
        if structureURL.pathExtension == "xcdatamodel" {
            structureURL.appendPathComponent("contents")
        }
        guard case .file = fileManager.existence(at: structureURL) else {
            logger.error("structure folder \(structureURL) does not exist")
            alert("structure folder \(structureURL) does not exist")
            return
        }

        let dialog = NSSavePanel()
        dialog.directoryURL = URL(fileURLWithPath: structureTextField.stringValue).deletingLastPathComponent()
        dialog.canCreateDirectories = true
        if (dialog.runModal() == NSApplication.ModalResponse.OK) {
            if let result = dialog.url {
                let path = result.path
                let outputURL: URL = URL(fileURLWithPath: path)

                // XXX in real application must be done in background Thread, core data context too
                DispatchQueue.main.async {
                    let generate = Generator()
                    generate.generate(urls: urls, structureURL: structureURL, outputURL: outputURL, modelName: modelName)

                    DispatchQueue.main.async {
                        // reveal in finder
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: outputURL.path)
                    }
                }

            }
        } else {
            // User clicked on "Cancel"
            return
        }
    }

    func alert(_ messageText: String) {
        let alert: NSAlert = NSAlert()
        alert.messageText = messageText
        alert.alertStyle = .warning
        _ = alert.runModal()
    }
}

