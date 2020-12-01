// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "CoreDataImport",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .executable(
            name: "coredataimport", targets: ["CoreDataImport"]
        ),
        .library(
            name: "CoreDataImportKit", targets: ["CoreDataImportKit"]
        )
    ],
    dependencies: [
        .package(url: "https://gitlab-4d.private.4d.fr/qmobile/QMobileAPI.git" , .revision("HEAD")),
        .package(url: "https://gitlab-4d.private.4d.fr/qmobile/QMobileDataStore.git" , .revision("HEAD")),
        .package(url: "https://gitlab-4d.private.4d.fr/qmobile/QMobileDataSync.git" , .revision("HEAD")),
        .package(url: "https://github.com/drmohundro/SWXMLHash.git", .revision("5.0.1")),
        .package(url: "https://github.com/phimage/MomXML.git", .revision("HEAD")),
        .package(url: "https://github.com/phimage/Prephirences.git", from: "5.1.0"),
        .package(url: "https://github.com/DaveWoodCom/XCGLogger.git", .revision("7.0.0")),
        .package(url: "https://github.com/Carthage/Commandant.git", .upToNextMinor(from: "0.17.0"))
    ],
    targets: [
        .target(
            name: "CoreDataImport",
            dependencies: ["CoreDataImportKit"],
            path: "Sources/CoreDataImport"
        ),
        .target(
            name: "CoreDataImportKit",
            dependencies: ["QMobileAPI","QMobileDataStore", "QMobileDataSync", "MomXML", "SWXMLHash", "XCGLogger", "Prephirences", "Commandant"],
            path: "Sources/CoreDataImportKit"
        ),
    ]
)
