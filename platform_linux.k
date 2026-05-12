// platform_linux.k — Linux platform stub.
//
// Status: PAUSED in Krypton 2.0.
//
// The previous implementation used `head:termios` (a libc binding) to
// drive raw mode + poll + ioctl + readdir. That added a C-language
// dependency to Krypton, which conflicts with the 2.0 goal of removing
// C from the runtime surface.
//
// The proper fix is for the Linux ELF backend (compiler/linux_x86/elf.k)
// to gain native syscall builtins for tcgetattr/poll/ioctl/getdents/
// nanosleep so terminal control can be expressed as direct SYSCALL
// instructions with no libc on the path. Plan: docs/linux_x86_2_0_port_plan.txt
//
// Until that lands, ktop Linux builds will compile but the runtime
// behavior is no-op stubs — pvGetch returns empty, pvKbhit returns "0",
// the main loop will spin without input. Don't run on Linux until 2.1.
//
// Build pause communicated via pvPlatform returning "0" so any caller
// that probes for Linux at least gets a consistent reply.

// ── Platform detection ───────────────────────────────────────

func pvPlatform() { emit "0" }

// ── Console setup (stubs) ────────────────────────────────────

func pvEnableVT100()          { emit "" }
func pvSetRaw()               { emit "" }
func pvRestoreTerm(saved)     { emit "" }

// ── Keyboard input (stubs) ───────────────────────────────────

func pvKbhit()                { emit "0" }
func pvGetch()                { emit "" }

// ── Terminal size (stub — return a default) ──────────────────

func pvTermsize()             { emit "80,24" }

// ── Sleep (stub — caller should not depend on actual sleep) ──

func pvSleep(ms)              { emit "" }

// ── Process listing (stub) ───────────────────────────────────

func pvListPids()             { emit "" }

// ── Windows stubs (never called on Linux) ────────────────────

func pvWinSnapshot(prevState) { emit "\n---SEP---\n" }

// ── System info (stubs returning empty/zero) ─────────────────

func pvUptime()               { emit "" }
func pvMem()                  { emit "0,0" }
func pvLoadavg()              { emit "" }
