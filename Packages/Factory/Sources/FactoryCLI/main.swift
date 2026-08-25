import Darwin
import FactoryCore
import Foundation

let arguments = Array(CommandLine.arguments.dropFirst())
let standardInput: Data = if FactoryCLICommand.requiresStandardInput(arguments: arguments) {
    (try? FactoryProcessInput.read(fileDescriptor: STDIN_FILENO)) ?? Data()
} else {
    Data()
}

let usesDesignWatchdog = arguments.count == 3 && arguments.first == "design"
if usesDesignWatchdog {
    _ = Darwin.signal(SIGALRM, SIG_DFL)
    var signalMask = sigset_t()
    _ = Darwin.sigemptyset(&signalMask)
    _ = Darwin.sigaddset(&signalMask, SIGALRM)
    _ = Darwin.pthread_sigmask(SIG_UNBLOCK, &signalMask, nil)
    _ = Darwin.alarm(35)
}

let result = FactoryCLICommand.run(arguments: arguments, standardInput: standardInput)
if usesDesignWatchdog {
    _ = Darwin.alarm(0)
}

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
