//
//  BadKernelBridge.swift
//  External Nixx — Swift wrapper for BadKernel C API.
//

import Foundation

enum BadKernelBridge {

    private(set) static var isReady = false
    private(set) static var kernelBase: UInt64 = 0
    private(set) static var kernelSlide: UInt64 = 0

    // MARK: - Initialize

    @discardableResult
    static func initialize() -> Bool {
        guard !isReady else { return true }
        log("[BadKernel] initializing…")
        let start = Date()
        BadKernelInit()

        guard BadKernelIsReady() else {
            log("[BadKernel] ❌ not ready")
            return false
        }

        kernelBase = BadKernelGetBase()
        kernelSlide = BadKernelGetSlide()

        log("[BadKernel] ✅ ready in \(String(format: "%.2f", Date().timeIntervalSince(start)))s")
        log("[BadKernel] base = 0x\(String(kernelBase, radix: 16))")
        log("[BadKernel] slide = 0x\(String(kernelSlide, radix: 16))")

        isReady = true
        return true
    }

    static func deinitialize() {
        guard isReady else { return }
        BadKernelDeinit()
        isReady = false
        kernelBase = 0
        kernelSlide = 0
    }

    // MARK: - Sandbox escape

    @discardableResult
    static func sandboxEscape(_ path: String) -> Int64 {
        let h = BadKernelSandboxEscape(path)
        log(h >= 0
            ? "[BadKernel] sandbox OK: \(path) (h=\(h))"
            : "[BadKernel] ❌ sandbox fail: \(path) (h=\(h))")
        return h
    }

    static func sandboxRelease(_ handle: Int64) {
        guard handle >= 0 else { return }
        BadKernelSandboxRelease(handle)
    }

    // MARK: - Kernel R/W

    static func kread32(_ addr: UInt64) -> UInt32 {
        isReady ? BadKernelKRead32(addr) : 0
    }
    static func kread64(_ addr: UInt64) -> UInt64 {
        isReady ? BadKernelKRead64(addr) : 0
    }
    @discardableResult
    static func kwrite32(_ addr: UInt64, _ val: UInt32) -> Bool {
        isReady ? BadKernelKWrite32(addr, val) : false
    }
    @discardableResult
    static func kwrite64(_ addr: UInt64, _ val: UInt64) -> Bool {
        isReady ? BadKernelKWrite64(addr, val) : false
    }

    // MARK: - Support

    static func isSupported() -> Bool {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        if v.majorVersion < 26 { return false }
        if v.majorVersion > 27 { return false }
        if v.majorVersion == 27 && v.minorVersion > 0 { return false }
        return true
    }

    static func isIOS27BuildSupported(_ build: String) -> Bool {
        ["24A5355q","24A5370h","24A5380h","24A5380l","24A5390f"].contains(build)
    }

    static func verifyKernelAccess() -> Bool {
        guard isReady else { return false }
        let magic = kread32(kernelBase)
        let expected: UInt32 = 0xFEEDFACF
        if magic == expected {
            log("[BadKernel] ✅ Mach-O magic verified")
            return true
        }
        log("[BadKernel] ❌ magic 0x\(String(magic, radix: 16)) != 0x\(String(expected, radix: 16))")
        return false
    }
}
