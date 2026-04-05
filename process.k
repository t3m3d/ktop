// process.k — process data collection, sorting
// Process line format: pid|name|cpu_hundredths|rss_kb
// cpu_hundredths = cpu% * 100  (e.g. 125 = 1.25%)
// rss_kb         = working set in KB

// ── Linux /proc parsing ─────────────────────────────────────

// linuxTotalCpu: read total CPU jiffies from /proc/stat
func linuxTotalCpu() {
    let s = trim(readFile("/proc/stat"))
    if s == "" { emit "0" }
    let line = nthline(s, "0")
    // "cpu  user nice system idle iowait irq softirq steal"
    let user    = toInt(nthField(line, "1"))
    let nice    = toInt(nthField(line, "2"))
    let system  = toInt(nthField(line, "3"))
    let idle    = toInt(nthField(line, "4"))
    let iowait  = toInt(nthField(line, "5"))
    let irq     = toInt(nthField(line, "6"))
    let softirq = toInt(nthField(line, "7"))
    let steal   = toInt(nthField(line, "8"))
    emit user + nice + system + idle + iowait + irq + softirq + steal + ""
}

// parseLinuxStat: parse /proc/pid/stat → "name|utime|stime|rss_kb" or ""
func parseLinuxStat(stat) {
    if stat == "" { emit "" }
    let lp = indexOf(stat, "(")
    if lp < 0 { emit "" }
    let rp = toInt(lastIndexOf(stat, ")"))
    if rp < 0 { emit "" }
    let name = substring(stat, toInt(lp) + 1, rp)
    // After closing paren, fields are space-separated:
    // 0=state 1=ppid ... 11=utime 12=stime ... 21=rss(pages)
    let rest  = substring(stat, rp + 1, len(stat))
    let utime = nthField(rest, "11")
    let stime = nthField(rest, "12")
    let rss_p = nthField(rest, "21")
    if utime == "" { emit "" }
    let rss_kb = toInt(rss_p) * 4 + ""
    emit name + "|" + utime + "|" + stime + "|" + rss_kb
}

// lookupPrevJiffies: find pid's previous jiffies in map "pid:jiffies\n..."
func lookupPrevJiffies(prevMap, pid) {
    let n = toInt(linecount(prevMap))
    let i = "0"
    while toInt(i) < n {
        let entry = nthline(prevMap, i)
        let epid  = firstpart(entry, ":")
        if epid == pid {
            emit afterpart(entry, ":")
        }
        i = toInt(i) + 1 + ""
    }
    emit "0"
}

// collectLinuxProcs: returns "PROCS\n---SEP---\nNEW_TOTAL\n---SEP---\nNEW_MAP"
func collectLinuxProcs(prevTotal, prevMap) {
    let pids     = trim(pvListPids())
    let pidCount = toInt(linecount(pids))
    let newTotal = linuxTotalCpu()
    let totalDelta = toInt(newTotal) - toInt(prevTotal)
    if totalDelta <= 0 { totalDelta = 1 }

    let procs  = ""
    let newMap = ""
    let cap    = 128
    let i      = "0"
    let taken  = 0

    while toInt(i) < pidCount && taken < cap {
        let pid  = nthline(pids, i)
        let stat = trim(readFile("/proc/" + pid + "/stat"))
        let info = parseLinuxStat(stat)
        if info != "" {
            let name  = firstpart(info, "|")
            let rest  = afterpart(info, "|")
            let utime = toInt(firstpart(rest, "|"))
            let rest2 = afterpart(rest, "|")
            let stime = toInt(firstpart(rest2, "|"))
            let rss_kb = afterpart(rest2, "|")
            let jiffies = utime + stime
            let prev    = toInt(lookupPrevJiffies(prevMap, pid))
            let delta   = jiffies - prev
            if delta < 0 { delta = 0 }
            let cpuH    = delta * 10000 / totalDelta
            let line    = pid + "|" + name + "|" + cpuH + "|" + rss_kb
            procs  = appendLine(procs, line)
            newMap = appendLine(newMap, pid + ":" + jiffies)
            taken += 1
        }
        i = toInt(i) + 1 + ""
    }
    emit procs + "\n---SEP---\n" + newTotal + "\n---SEP---\n" + newMap
}

// ── Windows process collection ──────────────────────────────
// prevState: "idleLo:idleHi:kernLo:kernHi:userLo:userHi\npid:ktLo:ktHi:utLo:utHi\n..."
// Returns:   "procs\n---SEP---\nnewState"

func collectWindowsProcs(prevState) {
    let result   = pvWinSnapshot(prevState)
    let sep      = indexOf(result, "\n---SEP---\n")
    let procs    = substring(result, 0, sep)
    let newState = afterpart(result, "\n---SEP---\n")
    emit procs + "\n---SEP---\n" + newState
}

// ── Sorting ─────────────────────────────────────────────────

// procSortKey: extract sort key from a process line
func procSortKey(line, key) {
    let pid  = firstpart(line, "|")
    let rest = afterpart(line, "|")
    let name = firstpart(rest, "|")
    let rest2 = afterpart(rest, "|")
    let cpuH = firstpart(rest2, "|")
    let rss  = afterpart(rest2, "|")
    if key == "cpu"  { emit cpuH }
    if key == "mem"  { emit rss  }
    if key == "pid"  { emit pid  }
    if key == "name" { emit name }
    emit cpuH
}

// isBetter: returns "1" if val should come before bestVal for key
func isBetter(val, bestVal, key) {
    if key == "name" {
        if val < bestVal { emit "1" }
        emit "0"
    }
    if key == "pid" {
        if toInt(val) < toInt(bestVal) { emit "1" }
        emit "0"
    }
    // cpu and mem: descending
    if toInt(val) > toInt(bestVal) { emit "1" }
    emit "0"
}

// sortProcs: selection sort, returns sorted process string
func sortProcs(procs, key) {
    let n       = toInt(linecount(procs))
    let sorted  = ""
    let remaining = procs
    let pass    = 0
    while pass < n {
        let remN    = toInt(linecount(remaining))
        let bestIdx = "0"
        let bestLine = nthline(remaining, "0")
        let bestVal  = procSortKey(bestLine, key)
        let j = "1"
        while toInt(j) < remN {
            let line = nthline(remaining, j)
            let val  = procSortKey(line, key)
            if isBetter(val, bestVal, key) == "1" {
                bestIdx  = j
                bestLine = line
                bestVal  = val
            }
            j = toInt(j) + 1 + ""
        }
        sorted    = appendLine(sorted, bestLine)
        remaining = removeLine(remaining, bestIdx)
        pass += 1
    }
    emit sorted
}
