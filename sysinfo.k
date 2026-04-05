// sysinfo.k — system summary (delegates to platform functions)

func sysUptime(isWin) { emit pvUptime() }
func sysMem(isWin)    { emit pvMem() }
func sysLoadavg(isWin) { emit pvLoadavg() }
