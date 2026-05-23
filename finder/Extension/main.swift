import Foundation

// NSExtensionMain initialises the extension framework and starts the run loop.
// It is a C function in Foundation — look it up dynamically to avoid a bridging header.
typealias NSExtensionMainFn = @convention(c) (Int32, UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>) -> Void
let fn = unsafeBitCast(dlsym(nil, "NSExtensionMain"), to: NSExtensionMainFn.self)
fn(CommandLine.argc, CommandLine.unsafeArgv)
