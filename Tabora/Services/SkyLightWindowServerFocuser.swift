import Carbon
import CoreGraphics
import Darwin
import Foundation

@_silgen_name("GetProcessForPID")
private func getProcessForPIDCompat(
    _ processIdentifier: pid_t,
    _ processSerialNumber: UnsafeMutablePointer<ProcessSerialNumber>
) -> OSStatus

@MainActor
protocol WindowServerFocusing {
    func focusWindow(processIdentifier: pid_t, windowID: CGWindowID) -> Bool
}

struct SkyLightWindowServerFocuser: WindowServerFocusing {
    private typealias SetFrontProcessWithOptionsFunction = @convention(c) (
        UnsafeMutablePointer<ProcessSerialNumber>,
        CGWindowID,
        UInt32
    ) -> CGError
    private typealias PostEventRecordFunction = @convention(c) (
        UnsafeMutablePointer<ProcessSerialNumber>,
        UnsafeMutablePointer<UInt8>
    ) -> CGError

    private enum SLPSMode {
        static let userGenerated: UInt32 = 0x200
    }

    func focusWindow(processIdentifier: pid_t, windowID: CGWindowID) -> Bool {
        guard let symbols = Self.SkyLightSymbols.load() else {
            TaboraLogger.log("activation", "SkyLight symbols unavailable for windowID=\(windowID)")
            return false
        }

        var processSerialNumber = ProcessSerialNumber()
        guard getProcessForPIDCompat(processIdentifier, &processSerialNumber) == noErr else {
            TaboraLogger.log("activation", "GetProcessForPID failed pid=\(processIdentifier) windowID=\(windowID)")
            return false
        }

        let frontResult = symbols.setFrontProcessWithOptions(
            &processSerialNumber,
            windowID,
            SLPSMode.userGenerated
        )
        let postResults = postMakeKeyWindowEvents(
            to: &processSerialNumber,
            windowID: windowID,
            postEventRecord: symbols.postEventRecord
        )
        TaboraLogger.log(
            "activation",
            """
            SkyLight focus windowID=\(windowID) pid=\(processIdentifier) \
            front=\(frontResult.rawValue) post=\(postResults.map(\.rawValue))
            """
        )
        guard frontResult == .success else {
            return false
        }

        let focused = waitForFrontWindow(processIdentifier: processIdentifier, windowID: windowID)
        TaboraLogger.log(
            "activation",
            "SkyLight verified windowID=\(windowID) pid=\(processIdentifier) focused=\(focused)"
        )
        return focused
    }

    private func postMakeKeyWindowEvents(
        to processSerialNumber: inout ProcessSerialNumber,
        windowID: CGWindowID,
        postEventRecord: PostEventRecordFunction
    ) -> [CGError] {
        var bytes = [UInt8](repeating: 0, count: 0xF8)
        bytes[0x04] = 0xF8
        bytes[0x3A] = 0x10
        withUnsafeBytes(of: windowID) { windowIDBytes in
            bytes.replaceSubrange(0x3C ..< 0x3C + MemoryLayout<UInt32>.size, with: windowIDBytes)
        }
        bytes.replaceSubrange(0x20 ..< 0x30, with: repeatElement(0xFF, count: 0x10))

        bytes[0x08] = 0x01
        let firstResult = postEventRecord(&processSerialNumber, &bytes)
        bytes[0x08] = 0x02
        let secondResult = postEventRecord(&processSerialNumber, &bytes)
        return [firstResult, secondResult]
    }

    private func waitForFrontWindow(processIdentifier: pid_t, windowID: CGWindowID) -> Bool {
        for _ in 0 ..< 8 {
            if frontWindowID(processIdentifier: processIdentifier) == windowID {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.025))
        }

        return false
    }

    private func frontWindowID(processIdentifier: pid_t) -> CGWindowID? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowInfo = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: AnyObject]] else {
            return nil
        }

        for info in windowInfo {
            guard
                let ownerPID = info[kCGWindowOwnerPID as String] as? NSNumber,
                ownerPID.int32Value == processIdentifier,
                let layer = info[kCGWindowLayer as String] as? NSNumber,
                layer.intValue == 0,
                let windowNumber = info[kCGWindowNumber as String] as? NSNumber
            else {
                continue
            }

            return CGWindowID(windowNumber.uint32Value)
        }

        return nil
    }

    private struct SkyLightSymbols {
        let setFrontProcessWithOptions: SetFrontProcessWithOptionsFunction
        let postEventRecord: PostEventRecordFunction

        static func load() -> Self? {
            let frameworkPath = "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight"
            guard let handle = dlopen(frameworkPath, RTLD_NOW) else {
                return nil
            }

            guard
                let setFrontProcessSymbol = dlsym(handle, "_SLPSSetFrontProcessWithOptions"),
                let postEventRecordSymbol = dlsym(handle, "SLPSPostEventRecordTo")
            else {
                return nil
            }

            return Self(
                setFrontProcessWithOptions: unsafeBitCast(
                    setFrontProcessSymbol,
                    to: SetFrontProcessWithOptionsFunction.self
                ),
                postEventRecord: unsafeBitCast(postEventRecordSymbol, to: PostEventRecordFunction.self)
            )
        }
    }
}
