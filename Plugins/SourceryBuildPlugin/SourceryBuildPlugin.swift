import Foundation
import PackagePlugin

#if canImport(XcodeProjectPlugin)
    import XcodeProjectPlugin
#endif

enum SourceryError: Error, CustomStringConvertible {
    var description: String {
        switch self {
        case .templatesNotFound(let sourceDir):
            return
                "Could not find any templates files (*.stencil, *.swifttemplate) inside \(sourceDir)"
        }
    }

    case templatesNotFound(String)
}

struct SourceryArguments {
    let sourceDirectory: URL
    let outputDirectory: URL
    let cacheDirectory: URL
    let templateFiles: [URL]
}

struct SourceryCommandContext {
    let targetName: String
    let sourcery: PluginContext.Tool
    let workDirectory: URL
    let args: SourceryArguments

    init(
        context: PluginContext,
        target: PackagePlugin.Target
    ) throws {
        self.targetName = target.name
        self.sourcery = try! context.tool(named: "sourcery")
        self.workDirectory = URL(
            fileURLWithPath: context.pluginWorkDirectory.string
        )
        let templates = target.findTemplateFiles()
        guard !templates.isEmpty else {
            throw SourceryError.templatesNotFound(target.directory.string)
        }
        self.args = .init(
            sourceDirectory: URL(fileURLWithPath: target.directory.string),
            outputDirectory: workDirectory.appending(path: "Generated"),
            cacheDirectory: workDirectory.appending(path: "Cache"),
            templateFiles: templates
        )
    }
}

#if canImport(XcodeProjectPlugin)
    extension SourceryCommandContext {

        init(
            context: XcodeProjectPlugin.XcodePluginContext,
            target: XcodeProjectPlugin.XcodeTarget
        ) throws {
            self.targetName = target.displayName
            self.sourcery = try! context.tool(named: "sourcery")
            self.workDirectory = URL(
                fileURLWithPath: context.pluginWorkDirectory.string
            )
            let rootSourceDirectory = target.findSourceRootDirectory()
            let templates = target.findTemplateFiles()
            guard !templates.isEmpty else {
                throw SourceryError.templatesNotFound(rootSourceDirectory.path)
            }
            self.args = .init(
                sourceDirectory: rootSourceDirectory,
                outputDirectory: workDirectory.appending(path: "Generated"),
                cacheDirectory: workDirectory.appending(path: "Cache"),
                templateFiles: target.findTemplateFiles()
            )
        }
    }
#endif

@main
struct SourceryBuildPlugin: BuildToolPlugin {

    func createBuildCommands(
        context: PluginContext,
        target: Target
    ) async throws -> [Command] {
        let sourceryContext: SourceryCommandContext = try .init(
            context: context,
            target: target
        )
        return [
            createCleanCommand(sourceryContext: sourceryContext),
            createSourceryBuildCommand(sourceryContext: sourceryContext),
        ]
    }

    /// Clean previously-generated files
    private func createCleanCommand(
        sourceryContext: SourceryCommandContext
    ) -> Command {
        return .prebuildCommand(
            displayName:
                "Clean previously-generated data for target \(sourceryContext.targetName)",
            executable: .init("/bin/rm"),
            arguments: ["-rf", sourceryContext.args.outputDirectory.path],
            outputFilesDirectory: .init(
                sourceryContext.workDirectory.path
            )
        )
    }

    /// Generate codes from latest changes
    private func createSourceryBuildCommand(
        sourceryContext: SourceryCommandContext
    ) -> Command {
        let cmd = "Generate sources for target: \(sourceryContext.targetName)"
        let args = sourceryContext.args
        let sourcesArgs = ["--sources", args.sourceDirectory.path]
        let templateArgs = args.templateFiles.flatMap {
            ["--templates", $0.path]
        }
        let outputArgs = ["--output", args.outputDirectory.path]
        let cacheArgs = ["--cacheBasePath", args.cacheDirectory.path]
        let extraArgs = ["--verbose"]

        return .prebuildCommand(
            displayName: cmd,
            executable: sourceryContext.sourcery.path,
            arguments: sourcesArgs + templateArgs + outputArgs + cacheArgs
                + extraArgs,
            outputFilesDirectory: .init(args.outputDirectory.path)
        )
    }
}

extension PackagePlugin.Target {

    var rootDirectory: URL {
        URL(fileURLWithPath: self.directory.string, isDirectory: true)
    }

    var inputFiles: PackagePlugin.FileList? {
        guard let target = self as? SourceModuleTarget else { return nil }
        return target.sourceFiles
    }

    func findSourceRootDirectory() -> URL {
        guard let inputFiles = inputFiles else { return rootDirectory }
        let allPaths = inputFiles.compactMap { file in
            URL(fileURLWithPath: file.path.string)
        }.filter {
            $0.pathExtension == "swift"
        }

        let commonPrefix = allPaths.map {
            $0.path
        }.reduce(allPaths.first?.path ?? "") { prefix, path in
            String(prefix.commonPrefix(with: path))
        }

        return URL(fileURLWithPath: commonPrefix, isDirectory: true)
    }

    func findTemplateFiles() -> [URL] {
        guard let inputFiles = inputFiles else { return [] }
        return inputFiles.filter {
            let ext = $0.path.extension
            return ext == "stencil" || ext == "swifttemplate"
        }.compactMap { file in
            URL(fileURLWithPath: file.path.string)
        }
    }
}

#if canImport(XcodeProjectPlugin)
    extension SourceryBuildPlugin: XcodeBuildToolPlugin {

        func createBuildCommands(
            context: XcodeProjectPlugin.XcodePluginContext,
            target: XcodeProjectPlugin.XcodeTarget
        ) throws -> [PackagePlugin.Command] {
            let sourceryContext: SourceryCommandContext = try .init(
                context: context,
                target: target
            )
            return [
                createCleanCommand(sourceryContext: sourceryContext),
                createSourceryBuildCommand(sourceryContext: sourceryContext),
            ]
        }
    }

    extension XcodeProjectPlugin.XcodeTarget {

        func findSourceRootDirectory() -> URL {
            let allPaths = inputFiles.compactMap { file in
                URL(fileURLWithPath: file.path.string)
            }.filter {
                $0.pathExtension == "swift"
            }

            let commonPrefix = allPaths.map {
                $0.path
            }.reduce(allPaths.first?.path ?? "") { prefix, path in
                String(prefix.commonPrefix(with: path))
            }

            return URL(fileURLWithPath: commonPrefix, isDirectory: true)
        }

        func findTemplateFiles() -> [URL] {
            return inputFiles.filter {
                let ext = $0.path.extension
                return ext == "stencil" || ext == "swifttemplate"
            }.compactMap { file in
                URL(fileURLWithPath: file.path.string)
            }
        }
    }
#endif
