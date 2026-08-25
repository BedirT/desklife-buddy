import Darwin
import FactoryCore
import Foundation

let arguments = Array(CommandLine.arguments.dropFirst())
let result = FactoryEvaluatorCommand.run(arguments: arguments)
do {
    if !result.standardOutput.isEmpty {
        try FileHandle.standardOutput.write(contentsOf: result.standardOutput)
    }
    if !result.standardError.isEmpty {
        try FileHandle.standardError.write(contentsOf: result.standardError)
    }
    Darwin.exit(result.exitCode)
} catch {
    Darwin.exit(74)
}
