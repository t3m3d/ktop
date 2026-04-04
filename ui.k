// ui.k — ANSI terminal display

// ── ANSI helpers ─────────────────────────────────────────────

func uiInit() {
    let E = fromCharCode(27)
    print(E + "[?25l")
    emit ""
}

func uiCleanup() {
    let E = fromCharCode(27)
    print(E + "[?25h")
    print(E + "[2J" + E + "[H")
    emit ""
}

func uiHome() {
    let E = fromCharCode(27)
    print(E + "[H")
    emit ""
}

func uiClear() {
    let E = fromCharCode(27)
    print(E + "[2J" + E + "[H")
    emit ""
}

// cpuBar: 14-char ASCII bar for cpu_hundredths value
func cpuBar(cpuH) {
    let width  = 14
    let filled = toInt(cpuH) * width / 10000
    if filled > width { filled = width }
    let bar = "["
    let i   = 0
    while i < filled { bar = bar + "#"  i += 1 }
    i = 0
    while i < width - filled { bar = bar + "-"  i += 1 }
    emit bar + "]"
}

// cpuColor: ANSI color for cpu_hundredths
func cpuColor(cpuH, useColor) {
    if useColor == "0" { emit "" }
    let E = fromCharCode(27)
    let pct = toInt(cpuH) / 100
    if pct > 50 { emit E + "[31m" }
    if pct > 20 { emit E + "[33m" }
    emit E + "[32m"
}

func rst(useColor) {
    if useColor == "0" { emit "" }
    emit fromCharCode(27) + "[0m"
}

func colorHdr(useColor) {
    if useColor == "0" { emit "" }
    emit fromCharCode(27) + "[36;1m"
}

func colorSum(useColor) {
    if useColor == "0" { emit "" }
    emit fromCharCode(27) + "[34;1m"
}

func colorBdr(useColor) {
    if useColor == "0" { emit "" }
    emit fromCharCode(27) + "[35m"
}

// drawSummary: top status bar
func drawSummary(uptime, mem, loadavg, procCount, useColor, cols) {
    let totalMB = toInt(firstpart(mem, ","))
    let availMB = toInt(afterpart(mem, ","))
    let usedMB  = totalMB - availMB
    let totalGB = totalMB / 1024
    let usedGB  = usedMB  / 1024

    let loadStr = ""
    if loadavg != "" { loadStr = "  Load: " + loadavg }

    let line = colorSum(useColor) + "ktop" + rst(useColor) +
               "  Uptime: " + uptime +
               "  Mem: " + usedGB + "GB/" + totalGB + "GB" +
               loadStr +
               "  Procs: " + procCount
    kp(colorBdr(useColor) + strRepeat("─", cols) + rst(useColor))
    kp(" " + line)
    kp("")
    emit ""
}

// drawHeader: column header row
func drawHeader(sortKey, useColor, cols) {
    let sortLabel = "CPU"
    if sortKey == "mem"  { sortLabel = "MEM"  }
    if sortKey == "pid"  { sortLabel = "PID"  }
    if sortKey == "name" { sortLabel = "NAME" }
    let hint = "[Sort: " + sortLabel + " | c=cpu m=mem p=pid n=name | arrows=scroll | q=quit]"
    let hdr  = padRight("PID      CPU%    BAR               RSS(MB)  NAME        " + hint, cols, " ")
    kp(colorHdr(useColor) + hdr + rst(useColor))
    emit ""
}

// formatCpu: convert cpu_hundredths to "XX.XX"
func formatCpu(cpuH) {
    let whole = toInt(cpuH) / 100
    let frac  = toInt(cpuH) - whole * 100
    emit whole + "." + twoDigit(frac + "")
}

// drawProcess: render one process line
func drawProcess(line, useColor, cols, alt) {
    let pid    = firstpart(line, "|")
    let rest   = afterpart(line, "|")
    let name   = firstpart(rest, "|")
    let rest2  = afterpart(rest, "|")
    let cpuH   = firstpart(rest2, "|")
    let rss_kb = afterpart(rest2, "|")
    let rss_mb = toInt(rss_kb) / 1024 + ""
    let cpuStr = padLeft(formatCpu(cpuH), "6", " ")
    let bar    = cpuBar(cpuH)
    let row    = padRight(pid,    "8", " ") + " " +
                 cpuStr + "%  " +
                 bar + "  " +
                 padLeft(rss_mb, "7", " ") + "  " +
                 padRight(name, "20", " ")
    let color  = cpuColor(cpuH, useColor)
    kp(" " + color + padRight(row, cols - 1 + "", " ") + rst(useColor))
    emit ""
}

// drawFrame: render full screen
func drawFrame(procs, uptime, mem, loadavg, sortKey, scrollOff, useColor, cols, rows) {
    uiHome()
    let procCount = linecount(procs)
    drawSummary(uptime, mem, loadavg, procCount, useColor, cols)
    drawHeader(sortKey, useColor, cols)

    // visible rows = rows minus header lines (border + title + blank + header + border)
    let visRows = toInt(rows) - 5
    if visRows < 1 { visRows = 1 }

    let i      = toInt(scrollOff)
    let shown  = 0
    let n      = toInt(procCount)
    while shown < visRows && i < n {
        let line = nthline(procs, i + "")
        if line != "" { drawProcess(line, useColor, cols, (i + shown) % 2 + "") }
        i     += 1
        shown += 1
    }
    // clear remaining lines
    let E = fromCharCode(27)
    print(E + "[J")
    kp(colorBdr(useColor) + strRepeat("─", cols) + rst(useColor))
    emit ""
}
