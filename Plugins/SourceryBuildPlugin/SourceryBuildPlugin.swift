import Foundation
import PackagePlugin

#if canImport(XcodeProjectPlugin)
    import XcodeProjectPlugin
#endif

enum SourceryPluginError: Error, CustomStringConvertible {
    var description: String {
        switch self {
        case .templatesNotFound(let sourceDir):
            "Could not find any templates files (*.stencil, *.swifttemplate) inside \(sourceDir).\n"
        case .configFileNotFound:
            "Config file `.sourcery.yml` is not found in target source directory. CLI options will be used instead.\n"
        case .invalidArgFile(let argFile):
            "Could not read argument file at \(argFile).\n"
        }
    }

    case invalidArgFile(argFile: String)
    case templatesNotFound(sourceDir: String)
    case configFileNotFound
}

enum SourceryConfig {
    case configFile(yml: URL, env: [String: String])
    case cliOptions(args: SourceryCommandArguments, env: [String: String])
}

struct SourceryCommandArguments {
    let sources: URL
    let templates: [URL]
    let extraArgs: [String]
}

struct SourceryPluginContext {
    let targetName: String
    let sourcery: PluginContext.Tool
    let workDirectory: URL
    let generatedDirectory: URL
    let cacheDirectory: URL
    let config: SourceryConfig

    init(context: PluginContext, target: PackagePlugin.Target) {
        self.targetName = target.name
        self.sourcery = try! context.tool(named: "sourcery")
        self.workDirectory = URL(
            fileURLWithPath: context.pluginWorkDirectory.string
        )
        self.generatedDirectory = workDirectory.appending(path: "Generated")
        self.cacheDirectory = workDirectory.appending(path: "Cache")

        let packageRootDirectory = URL(
            fileURLWithPath: context.package.directory.string
        )
        let sourceRootDirectory = URL(fileURLWithPath: target.directory.string)

        let systemEnv = ProcessInfo.processInfo.environment
            .filter { key, _ in key == "HOME" || key == "USER" }
        let env = [
            "PACKAGE_ROOT_DIR": packageRootDirectory.path,
            "TARGET_SOURCE_DIR": sourceRootDirectory.path,
            "TARGET_OUTPUT_DIR": generatedDirectory.path,
            "TARGET_CACHE_DIR": cacheDirectory.path,
        ].merging(systemEnv) { old, new in new }

        let configFile = sourceRootDirectory.appending(path: ".sourcery.yml")
        if let configFile = configFile.ifExist() {
            self.config = .configFile(
                yml: configFile,
                env: env
            )
        } else {
            Diagnostics.warning(
                SourceryPluginError.configFileNotFound.description
            )

            let templates = target.inputFiles?.findTemplateFiles() ?? []
            if templates.isEmpty {
                Diagnostics.error(
                    SourceryPluginError.templatesNotFound(
                        sourceDir: sourceRootDirectory.path
                    ).description
                )
            }

            let argFile = sourceRootDirectory.appending(
                path: ".sourcery.argfile"
            )
            let extraArgs = SourceryArgFile.parse(file: argFile, env: env)

            self.config = .cliOptions(
                args: .init(
                    sources: sourceRootDirectory,
                    templates: templates,
                    extraArgs: extraArgs
                ),
                env: env
            )
        }
    }
}

#if canImport(XcodeProjectPlugin)
    extension SourceryPluginContext {

        init(context: XcodePluginContext, target: XcodeTarget) {
            self.targetName = target.displayName
            self.sourcery = try! context.tool(named: "sourcery")
            self.workDirectory = URL(
                fileURLWithPath: context.pluginWorkDirectory.string
            )
            self.generatedDirectory = workDirectory.appending(path: "Generated")
            self.cacheDirectory = workDirectory.appending(path: "Cache")

            let projectRootDirectory = URL(
                fileURLWithPath: context.xcodeProject.directory.string
            )
            let sourceRootDirectory = target
                .inputFiles
                .findSourceRootDirectory()

            let systemEnv = ProcessInfo.processInfo.environment
                .filter { key, _ in key == "HOME" || key == "USER" }
            let env = [
                "PROJECT_ROOT_DIR": projectRootDirectory.path,
                "TARGET_SOURCE_DIR": sourceRootDirectory.path,
                "TARGET_OUTPUT_DIR": generatedDirectory.path,
                "TARGET_CACHE_DIR": cacheDirectory.path,
            ].merging(systemEnv) { old, new in new }

            let configFile = target.inputFiles.findConfigFile()
            if let configFile {
                self.config = .configFile(
                    yml: configFile,
                    env: env
                )
            } else {
                Diagnostics.warning(
                    SourceryPluginError.configFileNotFound.description
                )
                let templates = target.inputFiles.findTemplateFiles()
                if templates.isEmpty {
                    Diagnostics.error(
                        SourceryPluginError.templatesNotFound(
                            sourceDir: sourceRootDirectory.path
                        ).description
                    )
                }

                let extraArgs = SourceryArgFile.parse(
                    file: target.inputFiles.findArgFile(),
                    env: env
                )

                self.config = .cliOptions(
                    args: .init(
                        sources: sourceRootDirectory,
                        templates: templates,
                        extraArgs: extraArgs
                    ),
                    env: env
                )
            }

        }
    }
#endif

@main
struct SourceryBuildPlugin: BuildToolPlugin {

    func createBuildCommands(
        context: PluginContext,
        target: Target
    ) async throws -> [Command] {
        let sourceryContext: SourceryPluginContext = .init(
            context: context,
            target: target
        )
        return [
            createCleanCommand(sourceryContext: sourceryContext),
            createSourceryBuildCommand(sourceryContext: sourceryContext),
        ].compactMap { $0 }
    }

    /// Clean previously-generated files
    private func createCleanCommand(
        sourceryContext: SourceryPluginContext
    ) -> Command? {
        switch sourceryContext.config {
        case .configFile(_, _):
            return nil
        case .cliOptions(_, _):
            return .prebuildCommand(
                displayName:
                    "Clean previously-generated data for target \(sourceryContext.targetName)",
                executable: .init("/bin/rm"),
                arguments: ["-rf", sourceryContext.generatedDirectory.path],
                outputFilesDirectory: .init(
                    sourceryContext.workDirectory.path
                )
            )
        }
    }

    /// Generate codes from latest changes
    private func createSourceryBuildCommand(
        sourceryContext: SourceryPluginContext
    ) -> Command {
        let cmd = "Generate sources for target: \(sourceryContext.targetName)"
        switch sourceryContext.config {
        case .configFile(let yml, let env):
            return .prebuildCommand(
                displayName: cmd,
                executable: sourceryContext.sourcery.path,
                arguments: [
                    "--config", yml.path,
                    "--cacheBasePath", sourceryContext.cacheDirectory.path,
                    "--verbose",
                ],
                environment: env,
                outputFilesDirectory: Path(
                    sourceryContext.generatedDirectory.path
                )
            )
        case .cliOptions(let args, let env):
            let extraArgs =
                args.extraArgs.isEmpty ? ["--verbose"] : args.extraArgs
            let templateArgs = args.templates.flatMap {
                ["--templates", $0.path]
            }
            return .prebuildCommand(
                displayName: cmd,
                executable: sourceryContext.sourcery.path,
                arguments: [
                    "--sources", args.sources.path,
                    "--output", sourceryContext.generatedDirectory.path,
                    "--cacheBasePath", sourceryContext.cacheDirectory.path,
                ] + templateArgs + extraArgs,
                environment: env,
                outputFilesDirectory: Path(
                    sourceryContext.generatedDirectory.path
                )
            )
        }
    }
}

extension PackagePlugin.FileList {
    func findSourceRootDirectory() -> URL {
        let allPaths = self.compactMap { file in
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
        return self.filter {
            let ext = $0.path.extension
            return ext == "stencil" || ext == "swifttemplate"
        }.compactMap { file in
            URL(fileURLWithPath: file.path.string)
        }
    }

    func findConfigFile() -> URL? {
        return self.filter {
            return $0.path.lastComponent == ".sourcery.yml"
        }.first.map { file in URL(fileURLWithPath: file.path.string) }
    }

    func findArgFile() -> URL? {
        return self.filter {
            return $0.path.lastComponent == ".sourcery.argfile"
        }.first.map { file in URL(fileURLWithPath: file.path.string) }
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
}

extension URL {
    func ifExist() -> URL? {
        return FileManager.default.fileExists(atPath: self.path) ? self : nil
    }
}

enum SourceryArgFile {
    static func parse(file: URL?, env: [String: String]) -> [String] {
        guard let file = file?.ifExist() else { return [] }

        guard let content = try? String(contentsOf: file, encoding: .utf8)
        else {
            Diagnostics.warning(
                SourceryPluginError.invalidArgFile(argFile: file.path)
                    .description
            )
            return []
        }

        let ignoredFlags = [
            "--sources",
            "--templates",
            "--output",
            "--cacheBasePath",
        ]

        func expandEnvironmentVariables(in text: String) -> String {
            let pattern = #"\$\{([^}]+)\}"#
            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                return text
            }

            let nsrange = NSRange(text.startIndex..<text.endIndex, in: text)
            var result = text

            regex.enumerateMatches(
                in: text,
                options: [],
                range: nsrange
            ) { match, _, _ in
                guard let match = match,
                    let range = Range(match.range(at: 0), in: result),
                    let keyRange = Range(match.range(at: 1), in: result)
                else { return }

                let key = String(result[keyRange])
                let value = env[key] ?? ""

                result.replaceSubrange(range, with: value)
            }

            return result
        }

        let lines = content.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        var result: [String] = []
        for line in lines {
            guard line.hasPrefix("--") else { continue }

            let components = line.split(separator: " ", maxSplits: 1).map(
                String.init
            )
            guard let flag = components.first else { continue }

            if ignoredFlags.contains(flag) {
                continue
            }

            result.append(flag)

            if components.count > 1 {
                let expanded = expandEnvironmentVariables(in: components[1])
                result.append(expanded)
            }
        }

        return result
    }
}

#if canImport(XcodeProjectPlugin)
    extension SourceryBuildPlugin: XcodeBuildToolPlugin {

        func createBuildCommands(
            context: XcodeProjectPlugin.XcodePluginContext,
            target: XcodeProjectPlugin.XcodeTarget
        ) throws -> [PackagePlugin.Command] {
            let sourceryContext: SourceryPluginContext = .init(
                context: context,
                target: target
            )
            return [
                createCleanCommand(sourceryContext: sourceryContext),
                createSourceryBuildCommand(sourceryContext: sourceryContext),
            ].compactMap { $0 }
        }
    }
#endif
