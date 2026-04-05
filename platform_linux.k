// platform_linux.k — Linux platform implementation in Krypton
// Imported by build.sh (copied to platform.k before compilation)
// Provides all pv* functions + pvUptime/pvMem/pvLoadavg for Linux

import "lx_helpers.krh"

// ── Platform detection ───────────────────────────────────────

func pvPlatform() { emit "0" }

// ── Console setup ────────────────────────────────────────────

func pvEnableVT100()          { emit "" }
func pvSetRaw()               { lxSetRaw()   emit "" }
func pvRestoreTerm(saved)     { lxRestoreTerm() emit "" }

// ── Keyboard input ───────────────────────────────────────────

func pvKbhit() {
    emit lxKbhit() > 0 ? "1" : "0"
}

func pvGetch() {
    emit lxGetch()
}

// ── Terminal size ────────────────────────────────────────────

func pvTermsize() {
    emit lxTermsize()
}

// ── Sleep ────────────────────────────────────────────────────

func pvSleep(ms) {
    lxSleep(ms)
    emit ""
}

// ── Process listing ──────────────────────────────────────────

func pvListPids() {
    emit lxListPids()
}

// ── Windows stubs (never called on Linux) ────────────────────

func pvWinSnapshot(prevState) { emit "\n---SEP---\n" }

// ── System info ───────────────────────────────────────────────

func pvUptime() {
    let s = trim(readFile("/proc/uptime"))
    if s == "" { emit "" }
    let dot  = indexOf(s, ".")
    let sec  = toInt(dot >= 0 ? substring(s, 0, dot) : s)
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
    let info    = readFile("/proc/meminfo")
    if info == "" { emit "0,0" }
    let totalPos = indexOf(info, "MemTotal:")
    let availPos = indexOf(info, "MemAvailable:")
    let totalKB  = "0"
    let availKB  = "0"
    if totalPos >= 0 {
        let r = substring(info, totalPos + 9, len(info))
        totalKB = nthField(r, "0")
    }
    if availPos >= 0 {
        let r = substring(info, availPos + 13, len(info))
        availKB = nthField(r, "0")
    }
    let totalMB = toInt(totalKB) / 1024 + ""
    let availMB = toInt(availKB) / 1024 + ""
    emit totalMB + "," + availMB
}

func pvLoadavg() {
    let s = trim(readFile("/proc/loadavg"))
    if s == "" { emit "" }
    let l1  = nthField(s, "0")
    let l5  = nthField(s, "1")
    let l15 = nthField(s, "2")
    emit l1 + " " + l5 + " " + l15
}
