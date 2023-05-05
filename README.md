# CoreDataImporter

This project allow to inject JSON data from 4D rest API to a [Core Data](https://developer.apple.com/documentation/coredata) database.

## Deploy

This tool is mainly used by [4D Mobile App](https://github.com/4d/4D-Mobile-App/blob/main/Resources/scripts/) to create the data set.

To inject a custom build you must place in [Resources/scripts](https://github.com/4d/4D-Mobile-App/blob/main/Resources/scripts/) of `4D Mobile App` component.

## Usage

```bash
coredataimporter --structure <path> --asset <path> --output <path> (--quiet --verbosity)
```

## Dependencies

This project depends on code from [iOS SDK](https://github.com/4d/ios-sdk).

| Name | License | Usefulness |
|-|-|-|
| [QMobileAPI](https://github.com/4d/ios-QMobileAPI) | [4D](https://github.com/4d/ios-QMobileAPI/blob/master/LICENSE.md) | Network api to decode JSON |
| [QMobileDataStore](https://github.com/4d/ios-QMobileDataStore) | [4D](https://github.com/4d/ios-QMobileDataStore/blob/master/LICENSE.md) | Store data in core data |
| [QMobileDataSync](https://github.com/4d/ios-QMobileDataSync) | [4D](https://github.com/4d/ios-QMobileDataSync/blob/master/LICENSE.md) | Synchronize data into database |

And some others frameworks

| Name | License | Usefulness |
|-|-|-|
| [Prephirences](https://github.com/phimage/Prephirences) | [MIT](https://github.com/phimage/Prephirences/blob/master/LICENSE) | Application settings |
| [MomXML](https://github.com/phimage/MomXML) | [MIT](https://github.com/phimage/MomXML/blob/master/LICENSE) | Play with core data model |
| [XCGLogger](https://github.com/DaveWoodCom/XCGLogger) | [MIT](https://github.com/DaveWoodCom/XCGLogger/blob/master/LICENSE.txt) | Log |
| [Commandant](https://github.com/Carthage/Commandant ) | [MIT](https://github.com/Carthage/Commandant/blob/master/LICENSE.md) | command line argument parser |

## Build

```bash
swift package update
swift build -c release
```

or simply call `build.sh`

If success a binary `coredataimporter` will be available at path: `.build/release/coredataimport`

## Testing

`launch.sh` will launch some tests using data available into `Resources`, `Resources2`, etc...
