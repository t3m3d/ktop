// platform_win.k — Windows platform implementation in Krypton
// Imported by build.bat (copied to platform.k before compilation)
// Provides all pv* functions + pvUptime/pvMem/pvLoadavg for Windows
//
// 2026-05-12: terminal control (raw mode, kbhit, getch, size, sleep,
// VT100 enable) moved into stdlib/terminal.k. This file keeps the
// Windows-specific process-snapshot and system-info code that doesn't
// belong in a generic terminal stdlib.

import "head:windows"
import "head:process"
import "k:terminal"

// ── Platform detection ───────────────────────────────────────

func pvPlatform() { emit "1" }

// ── Terminal control (thin shims onto k:terminal) ────────────

func pvEnableVT100()      { termEnableVT100()  emit "" }
func pvSetRaw()           { emit termSetRaw() }
func pvRestoreTerm(saved) { termRestore(saved) emit "" }
func pvKbhit()            { emit termKbhit() }
func pvGetch()            { emit termGetch() }
func pvTermsize()         { emit termSize() }
func pvSleep(ms)          { termSleep(ms)  emit "" }

// ── Linux stubs (never called on Windows) ────────────────────

func pvListPids()            { emit "" }

// ── Windows process snapshot ─────────────────────────────────
// prevState format: "idleLo:idleHi:kernLo:kernHi:userLo:userHi\npid:ktLo:ktHi:utLo:utHi\n..."
// Returns:         "procs\n---SEP---\nnewState"
// procs line:      "pid|name|cpuH|rss_kb"

func _ftVal(lo, hi) {
    // Combine FILETIME (hi, lo) into a 64-bit value string via mul64/add64
    emit add64(mul64(hi, "4294967296"), lo)
}

func _lookupPrevProcTime(prevMap, pid) {
    let n = toInt(linecount(prevMap))
    let i = "0"
    while toInt(i) < n {
        let entry = nthline(prevMap, i)
        let epid  = firstpart(entry, ":")
        if epid == pid + "" {
            emit afterpart(entry, ":")
        }
        i = toInt(i) + 1 + ""
    }
    emit "0:0:0:0"
}

func pvWinSnapshot(prevState) {
    // Parse previous system times from prevState line 0
    let prevSysLine = nthline(prevState, "0")
    let ps = prevSysLine
    let prevIdleLo  = firstpart(ps, ":")   ps = afterpart(ps, ":")
    let prevIdleHi  = firstpart(ps, ":")   ps = afterpart(ps, ":")
    let prevKernLo  = firstpart(ps, ":")   ps = afterpart(ps, ":")
    let prevKernHi  = firstpart(ps, ":")   ps = afterpart(ps, ":")
    let prevUserLo  = firstpart(ps, ":")
    let prevUserHi  = afterpart(ps, ":")

    // Previous per-process map is everything after line 0
    let prevMap = ""
    let nPrev = toInt(linecount(prevState))
    let pi = "1"
    while toInt(pi) < nPrev {
        prevMap = appendLine(prevMap, nthline(prevState, pi))
        pi = toInt(pi) + 1 + ""
    }

    // Current system times
    let idleFT = structNew("FILETIME")
    let kernFT = structNew("FILETIME")
    let userFT = structNew("FILETIME")
    GetSystemTimes(idleFT, kernFT, userFT)

    let idleLo = structGet(idleFT, "FILETIME", "dwLowDateTime")
    let idleHi = structGet(idleFT, "FILETIME", "dwHighDateTime")
    let kernLo = structGet(kernFT, "FILETIME", "dwLowDateTime")
    let kernHi = structGet(kernFT, "FILETIME", "dwHighDateTime")
    let userLo = structGet(userFT, "FILETIME", "dwLowDateTime")
    let userHi = structGet(userFT, "FILETIME", "dwHighDateTime")

    // Total CPU delta = (kern - idle + user) delta
    // Uses signed 32-bit arithmetic on low word only (safe for intervals < 429s)
    let prevBusy = toInt(prevKernLo) - toInt(prevIdleLo) + toInt(prevUserLo)
    let curBusy  = toInt(kernLo)     - toInt(idleLo)     + toInt(userLo)
    let totalDelta = curBusy - prevBusy
    if totalDelta <= 0 { totalDelta = 1 }

    // Iterate processes via toolhelp32
    let snap = CreateToolhelp32Snapshot(toHandle("2"), toHandle("0"))
    let pe   = structNew("PROCESSENTRY32")
    structSet(pe, "PROCESSENTRY32", "dwSize", sizeOf("PROCESSENTRY32"))

    let procs  = ""
    let newMap = ""
    let ok = Process32First(snap, pe)
    let cap = 0

    while ok != "0" && cap < 256 {
        let pid  = structGet(pe, "PROCESSENTRY32", "th32ProcessID")
        let name = structGet(pe, "PROCESSENTRY32", "szExeFile")

        // Strip .exe extension
        let nl = len(name)
        if nl > 4 {
            if substring(name, nl - 4, nl) == ".exe" {
                name = substring(name, 0, nl - 4)
            }
        }

        // Open process to get times and memory
        let ACCESS = "4112"   // PROCESS_QUERY_LIMITED_INFORMATION | PROCESS_VM_READ
        let ph = OpenProcess(toHandle(ACCESS), toHandle("0"), toHandle(pid))
        let phInt = handleInt(ph)

        if phInt != "0" {
            let ctFT = structNew("FILETIME")
            let etFT = structNew("FILETIME")
            let ktFT = structNew("FILETIME")
            let utFT = structNew("FILETIME")
            GetProcessTimes(ph, ctFT, etFT, ktFT, utFT)

            let ktLo = structGet(ktFT, "FILETIME", "dwLowDateTime")
            let ktHi = structGet(ktFT, "FILETIME", "dwHighDateTime")
            let utLo = structGet(utFT, "FILETIME", "dwLowDateTime")
            let utHi = structGet(utFT, "FILETIME", "dwHighDateTime")

            let pmc = structNew("PROCESS_MEMORY_COUNTERS")
            structSet(pmc, "PROCESS_MEMORY_COUNTERS", "cb", sizeOf("PROCESS_MEMORY_COUNTERS"))
            GetProcessMemoryInfo(ph, pmc, sizeOf("PROCESS_MEMORY_COUNTERS"))
            let wss = structGet(pmc, "PROCESS_MEMORY_COUNTERS", "WorkingSetSize")
            let rss_kb = toInt(div64(wss, "1024"))

            CloseHandle(ph)

            // CPU% via delta from previous sample
            let prevTimes = _lookupPrevProcTime(prevMap, pid)
            let pp = prevTimes
            let prevKtLo = firstpart(pp, ":") pp = afterpart(pp, ":")
            let prevKtHi = firstpart(pp, ":") pp = afterpart(pp, ":")
            let prevUtLo = firstpart(pp, ":") pp = afterpart(pp, ":")
            let prevUtHi = afterpart(pp, ":")

            let procDelta = (toInt(ktLo) - toInt(prevKtLo)) + (toInt(utLo) - toInt(prevUtLo))
            if procDelta < 0 { procDelta = 0 }
            let cpuH = procDelta * 10000 / totalDelta

            procs  = appendLine(procs, pid + "|" + name + "|" + cpuH + "|" + rss_kb)
            newMap = appendLine(newMap, pid + ":" + ktLo + ":" + ktHi + ":" + utLo + ":" + utHi)
        }

        ok  = Process32Next(snap, pe)
        cap += 1
    }

    CloseHandle(snap)

    let newSysLine = idleLo + ":" + idleHi + ":" + kernLo + ":" + kernHi + ":" + userLo + ":" + userHi
    let newState   = newSysLine + "\n" + newMap

    emit procs + "\n---SEP---\n" + newState
}

// ── System info ───────────────────────────────────────────────

func pvUptime() {
    let ms   = GetTickCount64()
    let sec  = toInt(div64(ms, "1000"))
    let days = sec / 86400
    sec = sec - days * 86400
    let hrs  = sec / 3600
    sec = sec - hrs * 3600
    let mins = sec / 60
    let r = ""
    if days > 0 { r = days + "d " }
    emit r + hrs + "h " + mins + "m"
}

func pvMem() {
    let ms = structNew("MEMORYSTATUSEX")
    structSet(ms, "MEMORYSTATUSEX", "dwLength", sizeOf("MEMORYSTATUSEX"))
    GlobalMemoryStatusEx(ms)
    let totalMB = div64(structGet(ms, "MEMORYSTATUSEX", "ullTotalPhys"), "1048576")
    let availMB = div64(structGet(ms, "MEMORYSTATUSEX", "ullAvailPhys"), "1048576")
    emit totalMB + "," + availMB
}

func pvLoadavg() { emit "" }
