import Darwin
import FactoryCore
import Foundation

let arguments = Array(CommandLine.arguments.dropFirst())
let standardInput: Data = if FactoryBrokerCommand.requiresStandardInput(arguments: arguments) {
    (try? FactoryProcessInput.read(fileDescriptor: STDIN_FILENO)) ?? Data()
} else {
    Data()
}

let result = FactoryBrokerCommand.run(arguments: arguments, standardInput: standardInput)
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
