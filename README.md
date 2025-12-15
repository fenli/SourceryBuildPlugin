# SourceryBuildPlugin
> SPM and Xcode Build plugins to run Sourcery CLI easier.
> Learn more about it from the Sourcery [here](https://github.com/krzysztofzablocki/Sourcery).

[![](https://img.shields.io/github/v/release/fenli/SourceryBuildPlugin?style=flat&label=Latest%20Release&color=blue)](https://github.com/fenli/SourceryBuildPlugin/releases)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Ffenli%2FSourceryBuildPlugin%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/fenli/SourceryBuildPlugin)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Ffenli%2FSourceryBuildPlugin%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/fenli/SourceryBuildPlugin)
[![](https://img.shields.io/github/license/fenli/SourceryBuildPlugin?style=flat)](https://github.com/fenli/SourceryBuildPlugin/blob/main/LICENSE)

## How to install
### SPM
Add this configuration to your `Package.swift`:
```swift
dependencies: [
    .package(url: "https://github.com/fenli/SourceryBuildPlugin", from: "2.3.0"),
],
```
> *This package version will follow [Sourcery binary versioning](https://github.com/krzysztofzablocki/Sourcery/releases)*

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

### Build on CI
If you are building on CI server, you have to add this as the xcodebuild command arguments to bypass xcode validation:
```
-skipPackagePluginValidation
-skipMacroValidation
```
Or if you are building on Xcode Cloud, you can disable it by adding this to `ci_scripts/ci_post_clone.sh`:
```sh
defaults write com.apple.dt.Xcode IDESkipPackagePluginFingerprintValidatation -bool YES
defaults write com.apple.dt.Xcode IDESkipMacroFingerprintValidation -bool YES
```

## Advantages
Offering sourcery plugins in a separate package has some advantages you should consider:
- No need to clone the whole Sourcery repository.
- Sourcery itself is included as a binary dependency, so consumer doesn't need to build it first.
- No other dependencies that need to be downloaded, resolved and compiled.
- Plugin runs in sanboxed environment so generated file is stored in intermediary build directory (it doesn't change source directory).
- Easily integrated into projects / packages since sourcery cli arguments is provided automatically:

## Configuration
### Auto configured
This plugin will run with minimum setup with auto configuration.
| Arguments           | Provided Value |
|---------------------|----------------|
| `--sources`         | Using target source root directory | 
| `--templates`       | Using any stencils/swifttemplate files found in source root directory or sub-directories | 
| `--output`          | Auto generated directory inside plugin work directory (sandboxed) | 
| `--cacheBasePath`   | Auto generated directory inside plugin work directory (sandboxed) |

**Optionally**, if you need to pass extra arguments (other than those 4) to sourcery cli, create `.sourcery.argfile` inside your target source directory.
Sample of valid `.sourcery.argfile`:

```argfile
--args arg1=value1
--args arg2=value with spaces
--args arg3
--verbose
```

> [!NOTE]
> All auto provided arguments will be ignored if specified in the argfile.
> See table below for the provided ENV variable that can be used on `.sourcery.argfile` file.

### With configuration file
Create `.sourcery.yml` in the target source directory and it will be used instead of auto provided arguments. Read more regarding this format [here](https://krzysztofzablocki.github.io/Sourcery/usage.html). Sample of valid `.sourcery.yml`:

```yml
sources:
  - "${TARGET_SOURCE_DIR}"
templates:
  - ../../Templates
output:
  "${TARGET_OUTPUT_DIR}"
args:
  autoImports: ["SwiftUI"]
```

> [!NOTE]
> It's required to use ENV variable for output since you cannot write to source directory in sandbox mode.
> See table below for the provided ENV variable that can be used on `.sourcery.yml` file.

### Environment variables
These are environment variables that are visible in `.sourcery.yml` and `.sourcery.argfile`
| ENV                   | Value          |
|-----------------------|----------------|
| `PROJECT_ROOT_DIR`    | Project root directory (Xcode target only) |
| `PACKAGE_ROOT_DIR`    | Package root directory (Swift package target only) |
| `TARGET_SOURCE_DIR`   | Target source directory (PackageName -> Sources -> TargetName) |
| `TARGET_OUTPUT_DIR`   | Auto generated directory inside plugin work directory (sandboxed) |
| `TARGET_CACHE_DIR`    | Auto generated directory inside plugin work directory (sandboxed) |
| `HOME`                | Home directory |
| `USER`                | Logged username |
