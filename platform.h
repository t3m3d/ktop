#pragma once
// kprocview platform abstraction
// Provides: sleep, keyboard input, terminal size, platform detection,
//           Linux PID enumeration, Windows process snapshot

#ifdef _WIN32
# define WIN32_LEAN_AND_MEAN
# include <windows.h>
# include <tlhelp32.h>
# include <psapi.h>
# include <conio.h>
# include <stdio.h>
# include <stdlib.h>
# include <string.h>

static char* pvPlatform(void)   { return "1"; }

static char* pvEnableVT100(void) {
    HANDLE h = GetStdHandle(STD_OUTPUT_HANDLE);
    DWORD  m = 0;
    if (GetConsoleMode(h, &m))
        SetConsoleMode(h, m | 4);
    SetConsoleOutputCP(65001);
    return "";
}

static char* pvSetRaw(void)      { return ""; }
static char* pvRestoreTerm(void) { return ""; }

static char* pvKbhit(void) { return _kbhit() ? "1" : "0"; }

static char* pvGetch(void) {
    static char buf[4];
    if (!_kbhit()) return "";
    int c = _getch();
    if (c == 0 || c == 224) {
        int c2 = _getch();
        if (c2 == 72) return "UP";
        if (c2 == 80) return "DOWN";
        if (c2 == 73) return "PGUP";
        if (c2 == 81) return "PGDN";
        return "";
    }
    buf[0] = (char)c; buf[1] = '\0';
    return buf;
}

static char* pvTermsize(void) {
    static char buf[32];
    CONSOLE_SCREEN_BUFFER_INFO csbi;
    if (!GetConsoleScreenBufferInfo(GetStdHandle(STD_OUTPUT_HANDLE), &csbi))
        return "80,24";
    int cols = csbi.srWindow.Right  - csbi.srWindow.Left + 1;
    int rows = csbi.srWindow.Bottom - csbi.srWindow.Top  + 1;
    snprintf(buf, 32, "%d,%d", cols, rows);
    return buf;
}

static char* pvSleep(const char* ms) { Sleep(atoi(ms)); return ""; }
static char* pvListPids(void) { return ""; }

/* ── Windows process snapshot ──────────────────────────────── */
#define KR_MAX_PROCS 128
typedef struct {
    int  pid;
    char name[260];
    int  cpu_hundredths;   /* cpu% * 100 */
    int  rss_kb;
    ULONGLONG kt, ut;      /* 100ns kernel/user times */
} KrProc;

static KrProc     g_procs[KR_MAX_PROCS];
static int        g_nprocs = 0, g_first = 1;
static ULONGLONG  g_prev_idle = 0, g_prev_kern = 0, g_prev_user = 0;

#define KR_MAX_HIST 128
static int       g_hpid[KR_MAX_HIST];
static ULONGLONG g_hkt[KR_MAX_HIST], g_hut[KR_MAX_HIST];
static int       g_nhist = 0;

static ULONGLONG _ft2ull(FILETIME ft) {
    return ((ULONGLONG)ft.dwHighDateTime << 32) | ft.dwLowDateTime;
}

static char* pvWinSnapshot(void) {
    FILETIME fi, fk, fu;
    GetSystemTimes(&fi, &fk, &fu);
    ULONGLONG ci=_ft2ull(fi), ck=_ft2ull(fk), cu=_ft2ull(fu);

    ULONGLONG total_delta = 1;
    if (!g_first) {
        ULONGLONG prev = (g_prev_kern - g_prev_idle) + g_prev_user;
        ULONGLONG cur  = (ck - ci) + cu;
        total_delta = cur > prev ? cur - prev : 1;
    }

    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snap == INVALID_HANDLE_VALUE) { g_nprocs = 0; return ""; }

    PROCESSENTRY32 pe; pe.dwSize = sizeof(pe);
    int n = 0;
    BOOL ok = Process32First(snap, &pe);
    while (ok && n < KR_MAX_PROCS) {
        HANDLE ph = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION|PROCESS_VM_READ,
                                FALSE, pe.th32ProcessID);
        if (ph) {
            FILETIME ct,et,kt,ut;
            GetProcessTimes(ph, &ct, &et, &kt, &ut);
            PROCESS_MEMORY_COUNTERS pmc; pmc.cb = sizeof(pmc);
            GetProcessMemoryInfo(ph, &pmc, sizeof(pmc));
            CloseHandle(ph);

            ULONGLONG ukt=_ft2ull(kt), uut=_ft2ull(ut);
            g_procs[n].pid    = pe.th32ProcessID;
            g_procs[n].kt     = ukt;
            g_procs[n].ut     = uut;
            g_procs[n].rss_kb = (int)(pmc.WorkingSetSize / 1024);

            strncpy(g_procs[n].name, pe.szExeFile, 259);
            int nl = strlen(g_procs[n].name);
            if (nl > 4 && strcmp(g_procs[n].name+nl-4, ".exe") == 0)
                g_procs[n].name[nl-4] = 0;

            g_procs[n].cpu_hundredths = 0;
            if (!g_first) {
                for (int hi = 0; hi < g_nhist; hi++) {
                    if (g_hpid[hi] == pe.th32ProcessID) {
                        ULONGLONG pd = (ukt - g_hkt[hi]) + (uut - g_hut[hi]);
                        g_procs[n].cpu_hundredths = (int)(pd * 10000ULL / total_delta);
                        break;
                    }
                }
            }
            n++;
        }
        ok = Process32Next(snap, &pe);
    }
    CloseHandle(snap);

    g_nhist = n < KR_MAX_HIST ? n : KR_MAX_HIST;
    for (int i = 0; i < g_nhist; i++) {
        g_hpid[i]=g_procs[i].pid; g_hkt[i]=g_procs[i].kt; g_hut[i]=g_procs[i].ut;
    }
    g_nprocs=n; g_prev_idle=ci; g_prev_kern=ck; g_prev_user=cu; g_first=0;
    return "";
}

static char _pb[32];
static char* pvWinCount(void) { snprintf(_pb,32,"%d",g_nprocs); return _pb; }
static char* pvWinPid(const char* s) {
    int i=atoi(s); if(i<0||i>=g_nprocs) return "0";
    snprintf(_pb,32,"%d",g_procs[i].pid); return _pb;
}
static char* pvWinName(const char* s) {
    int i=atoi(s); return (i>=0&&i<g_nprocs) ? g_procs[i].name : "";
}
static char* pvWinCpu(const char* s) {
    int i=atoi(s); if(i<0||i>=g_nprocs) return "0";
    snprintf(_pb,32,"%d",g_procs[i].cpu_hundredths); return _pb;
}
static char* pvWinRss(const char* s) {
    int i=atoi(s); if(i<0||i>=g_nprocs) return "0";
    snprintf(_pb,32,"%d",g_procs[i].rss_kb); return _pb;
}

#else
/* ── Linux ───────────────────────────────────────────────────── */
# include <stdio.h>
# include <stdlib.h>
# include <string.h>
# include <unistd.h>
# include <dirent.h>
# include <termios.h>
# include <sys/ioctl.h>
# include <sys/select.h>

static char* pvPlatform(void)     { return "0"; }
static char* pvEnableVT100(void)  { return ""; }

static struct termios g_orig;
static int g_raw = 0;

static char* pvSetRaw(void) {
    if (g_raw) return "";
    tcgetattr(0, &g_orig);
    struct termios t = g_orig;
    t.c_lflag &= ~(ICANON|ECHO);
    t.c_cc[VMIN]=0; t.c_cc[VTIME]=0;
    tcsetattr(0, TCSANOW, &t);
    g_raw=1; return "";
}
static char* pvRestoreTerm(void) {
    if (!g_raw) return "";
    tcsetattr(0, TCSANOW, &g_orig);
    g_raw=0; return "";
}

static char* pvKbhit(void) {
    struct timeval tv={0,0}; fd_set fds;
    FD_ZERO(&fds); FD_SET(0,&fds);
    return select(1,&fds,NULL,NULL,&tv)>0 ? "1" : "0";
}

static char* pvGetch(void) {
    static char buf[4]; char c=0;
    if (read(0,&c,1)<=0) return "";
    if (c==27) {
        struct timeval tv={0,50000}; fd_set fds;
        FD_ZERO(&fds); FD_SET(0,&fds);
        if (select(1,&fds,NULL,NULL,&tv)<=0) return "";
        char s[4]={0}; read(0,s,1);
        if (s[0]!='[') return "";
        tv.tv_usec=50000; FD_SET(0,&fds);
        if (select(1,&fds,NULL,NULL,&tv)<=0) return "";
        read(0,s+1,1);
        if(s[1]=='A') return "UP";
        if(s[1]=='B') return "DOWN";
        if(s[1]=='5'){char t; read(0,&t,1); return "PGUP";}
        if(s[1]=='6'){char t; read(0,&t,1); return "PGDN";}
        return "";
    }
    buf[0]=c; buf[1]=0; return buf;
}

static char* pvTermsize(void) {
    static char buf[32]; struct winsize w;
    ioctl(1,TIOCGWINSZ,&w);
    int c=w.ws_col>0?w.ws_col:80, r=w.ws_row>0?w.ws_row:24;
    snprintf(buf,32,"%d,%d",c,r); return buf;
}

static char* pvSleep(const char* ms) { usleep(atoi(ms)*1000); return ""; }

static char g_pidlist[65536];
static char* pvListPids(void) {
    DIR* d=opendir("/proc"); if(!d) return "";
    g_pidlist[0]=0; int pos=0;
    struct dirent* e;
    while((e=readdir(d))!=NULL) {
        if(e->d_name[0]<'1'||e->d_name[0]>'9') continue;
        int ok=1;
        for(int i=1;e->d_name[i];i++)
            if(e->d_name[i]<'0'||e->d_name[i]>'9'){ok=0;break;}
        if(!ok) continue;
        int l=strlen(e->d_name);
        if(pos+l+1<65534){memcpy(g_pidlist+pos,e->d_name,l);pos+=l;g_pidlist[pos++]='\n';}
    }
    closedir(d); g_pidlist[pos]=0; return g_pidlist;
}

/* Windows stubs */
static char* pvWinSnapshot(void) { return ""; }
static char* pvWinCount(void)    { return "0"; }
static char* pvWinPid(const char* s)  { return "0"; }
static char* pvWinName(const char* s) { return ""; }
static char* pvWinCpu(const char* s)  { return "0"; }
static char* pvWinRss(const char* s)  { return "0"; }
#endif
