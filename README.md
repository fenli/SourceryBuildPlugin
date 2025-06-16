# SourceryBuildPlugin
> SPM and Xcode Build plugins to run Sourcery binary easier.
> Learn more about it from the Sourcery [here](https://github.com/krzysztofzablocki/Sourcery).

[![](https://img.shields.io/github/v/release/fenli/SourceryBuildPlugin?style=flat&label=Latest%20Release&color=blue)](https://github.com/fenli/SourceryBuildPlugin/releases)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Ffenli%2FSourceryBuildPlugin%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/fenli/SourceryBuildPlugin)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Ffenli%2FSourceryBuildPlugin%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/fenli/SourceryBuildPlugin)
[![](https://img.shields.io/github/license/fenli/SourceryBuildPlugin?style=flat)](https://www.apache.org/licenses/LICENSE-2.0.txt)

## How to install
### SPM
Add this configuration to your `Package.swift`:
```swift
dependencies: [
    .package(url: "https://github.com/fenli/SourceryBuildPlugin", .branch("main")),
],
```
Then add the plugins to your target:
```swift
.target(
    name: "MyPackage",
    plugins: [
        .plugin(name: "SourceryBuildPlugin", package: "SourceryBuildPlugin")
    ]
)
```

### XCode
Integration into Xcode project:
- In Xcode root project, navigate to your targets list in side bar.
- Select target to integrate (usually app or library target).
- Go to Build Phase -> Run Build Tool Plug-ins -> Add the plugin

## Advantages
Offering the plugins in a separate package has some advantages you should consider:
- No need to clone the whole Sourcery repository.
- Sourcery itself is included as a binary dependency, thus the consumer doesn't need to build it first.
- There are no other dependencies that need to be downloaded, resolved and compiled.
- Sourcery binary version is autoupdated for every Sourcery release via pipeline.
- Easily integrated into projects / packages since sourcery cli arguments is provided automatically:

| Arguments           | Provided Value |
|---------------------|----------------|
| `--sources`         | Using target source root directory | 
| `--templates`       | Using any stencils/swifttemplate files found in source root directory or subdirectories | 
| `--output`          | Generated directory inside plugin work directory (sandboxed) | 
| `--cacheBasePath`   | Generated directory inside plugin work directory (sandboxed) | 

## Known limitation
While this plugin has some benefits, it also has some drawbacks, for example:
- Plugins run in sanboxed environment so it cannot change contents source directory.
- Cannot passing arguments to templates file (eg: autoImport).
- Templates file must be provided for each target, cannot be centralized.
