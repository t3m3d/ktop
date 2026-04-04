// sysinfo.k — system summary (uptime, memory, load averages)

// ── Linux (/proc) ───────────────────────────────────────────

func linuxUptime() {
    let s = trim(readFile("/proc/uptime"))
    if s == "" { emit "" }
    let dot  = indexOf(s, ".")
    let sec  = toInt(dot >= 0 ? substring(s, 0, dot) : s)
    let days = sec / 86400
    sec = sec - days * 86400
    let hrs  = sec / 3600
    sec = sec - hrs * 3600
    let mins = sec / 60
    let r    = ""
    if days > 0 { r = days + "d " }
    emit r + hrs + "h " + mins + "m"
}

func linuxMem() {
    let info  = readFile("/proc/meminfo")
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

func linuxLoadavg() {
    let s = trim(readFile("/proc/loadavg"))
    if s == "" { emit "" }
    let l1 = nthField(s, "0")
    let l5 = nthField(s, "1")
    let l15 = nthField(s, "2")
    emit l1 + " " + l5 + " " + l15
}

// ── Windows (via platform.h stubs returning "" on Linux) ────
// Windows uptime, mem, loadavg are all handled via GetTickCount64 /
// GlobalMemoryStatusEx inside pvPlatform — but for simplicity we
// read them through pvWin* helpers defined inline here using builtins
// already declared in the runtime.

func winUptime() {
    let ms   = GetTickCount64()
    let sec  = toInt(div64(ms, "1000"))
    let days = sec / 86400
    sec = sec - days * 86400
    let hrs  = sec / 3600
    sec = sec - hrs * 3600
    let mins = sec / 60
    let r    = ""
    if days > 0 { r = days + "d " }
    emit r + hrs + "h " + mins + "m"
}

func winMem() {
    let ms = structNew("MEMORYSTATUSEX")
    structSet(ms, "MEMORYSTATUSEX", "dwLength", sizeOf("MEMORYSTATUSEX"))
    GlobalMemoryStatusEx(ms)
    let totalMB = div64(structGet(ms, "MEMORYSTATUSEX", "ullTotalPhys"), "1048576")
    let availMB = div64(structGet(ms, "MEMORYSTATUSEX", "ullAvailPhys"), "1048576")
    emit totalMB + "," + availMB
}

// ── Unified sysinfo ─────────────────────────────────────────

func sysUptime(isWin) {
    if isWin == "1" { emit winUptime() }
    emit linuxUptime()
}

func sysMem(isWin) {
    if isWin == "1" { emit winMem() }
    emit linuxMem()
}

func sysLoadavg(isWin) {
    if isWin == "1" { emit "" }
    emit linuxLoadavg()
}
