import "platform.k"

import "utils.k"
import "process.k"
import "sysinfo.k"
import "ui.k"

just run {
    // ── Arg parsing ──────────────────────────────────────────
    let sortKey     = "cpu"
    let refreshMs   = "1000"
    let useColor    = "1"
    let argIdx      = 0
    let argVal      = arg(argIdx + "")
    while argVal != "" {
        if argVal == "--sort" {
            argIdx += 1
            sortKey = arg(argIdx + "")
        }
        if argVal == "--refresh" {
            argIdx += 1
            refreshMs = arg(argIdx + "")
        }
        if argVal == "--no-color" { useColor = "0" }
        if argVal == "--help" || argVal == "-h" {
            kp("ktop - Process Viewer (Krypton)")
            kp("Usage: ktop [options]")
            kp("  --sort cpu|mem|pid|name   Sort key (default: cpu)")
            kp("  --refresh ms              Refresh interval ms (default: 1000)")
            kp("  --no-color                Disable color")
            kp("  -h, --help                Show help")
            emit 0
        }
        argIdx += 1
        argVal = arg(argIdx + "")
    }

    // ── Init ─────────────────────────────────────────────────
    let isWin = pvPlatform()
    pvEnableVT100()
    pvSetRaw()
    uiInit()
    uiClear()

    // ── State ────────────────────────────────────────────────
    let scrollOff    = "0"
    let prevTotal    = "0"
    let prevMap      = ""
    let prevWinState = "0:0:0:0:0:0"
    let procs        = ""
    let uptime       = ""
    let mem          = "0,0"
    let loadavg      = ""

    // ── Main loop ────────────────────────────────────────────
    while "1" == "1" {
        // Terminal size
        let tsz  = pvTermsize()
        let cols = firstpart(tsz, ",")
        let rows = afterpart(tsz, ",")
        let visRows = toInt(rows) - 5
        if visRows < 1 { visRows = 1 }

        // Keyboard input
        let key = pvGetch()
        if key == "q" || key == "Q" {
            uiCleanup()
            pvRestoreTerm("")
            emit 0
        }
        if key == "c" || key == "C" { sortKey = "cpu"   scrollOff = "0" }
        if key == "m" || key == "M" { sortKey = "mem"   scrollOff = "0" }
        if key == "p" || key == "P" { sortKey = "pid"   scrollOff = "0" }
        if key == "n" || key == "N" { sortKey = "name"  scrollOff = "0" }
        if key == "UP" {
            if toInt(scrollOff) > 0 { scrollOff = toInt(scrollOff) - 1 + "" }
        }
        if key == "DOWN" {
            let maxOff = toInt(linecount(procs)) - visRows
            if maxOff < 0 { maxOff = 0 }
            if toInt(scrollOff) < maxOff { scrollOff = toInt(scrollOff) + 1 + "" }
        }
        if key == "PGUP" {
            scrollOff = toInt(scrollOff) - visRows + ""
            if toInt(scrollOff) < 0 { scrollOff = "0" }
        }
        if key == "PGDN" {
            let maxOff = toInt(linecount(procs)) - visRows
            if maxOff < 0 { maxOff = 0 }
            scrollOff = toInt(scrollOff) + visRows + ""
            if toInt(scrollOff) > maxOff { scrollOff = maxOff + "" }
        }

        // Collect processes
        if isWin == "1" {
            let winResult = collectWindowsProcs(prevWinState)
            let sep       = indexOf(winResult, "\n---SEP---\n")
            procs         = substring(winResult, 0, sep)
            prevWinState  = afterpart(winResult, "\n---SEP---\n")
        } else {
            let result    = collectLinuxProcs(prevTotal, prevMap)
            let sep1      = indexOf(result, "\n---SEP---\n")
            let afterSep  = afterpart(result, "\n---SEP---\n")
            procs         = substring(result, 0, sep1)
            prevTotal     = firstpart(afterSep, "\n---SEP---\n")
            prevMap       = afterpart(afterSep, "\n---SEP---\n")
        }

        // Sort
        procs = sortProcs(procs, sortKey)

        // System info
        uptime  = sysUptime(isWin)
        mem     = sysMem(isWin)
        loadavg = sysLoadavg(isWin)

        // Draw
        drawFrame(procs, uptime, mem, loadavg, sortKey, scrollOff, useColor, cols, rows)

        // Sleep
        pvSleep(refreshMs)
    }

    emit 0
}
