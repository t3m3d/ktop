#pragma once
// lx_helpers.h — minimal Linux syscall shim for ktop
// Provides only what can't be expressed with existing Krypton .krh headers:
//   - terminal raw mode (termios)
//   - non-blocking single-char read (select + read)
//   - terminal size (ioctl TIOCGWINSZ)
//   - usleep
//   - /proc PID listing (opendir/readdir)
//
// All functions return char* so Krypton can call them directly.
// Zero logic here — logic lives in platform_linux.k.

#ifdef __linux__

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <termios.h>
#include <sys/ioctl.h>
#include <sys/select.h>
#include <dirent.h>

static struct termios _lx_orig;
static int _lx_raw = 0;

static char* lxSetRaw(void) {
    if (_lx_raw) return "";
    tcgetattr(0, &_lx_orig);
    struct termios t = _lx_orig;
    t.c_lflag &= ~(ICANON | ECHO);
    t.c_cc[VMIN] = 0;
    t.c_cc[VTIME] = 0;
    tcsetattr(0, TCSANOW, &t);
    _lx_raw = 1;
    return "";
}

static char* lxRestoreTerm(void) {
    if (!_lx_raw) return "";
    tcsetattr(0, TCSANOW, &_lx_orig);
    _lx_raw = 0;
    return "";
}

static char* lxKbhit(void) {
    struct timeval tv = {0, 0};
    fd_set fds;
    FD_ZERO(&fds);
    FD_SET(0, &fds);
    return select(1, &fds, NULL, NULL, &tv) > 0 ? "1" : "0";
}

static char _lx_keybuf[8];
static char* lxGetch(void) {
    char c = 0;
    if (read(0, &c, 1) <= 0) return "";
    if (c == 27) {
        struct timeval tv = {0, 50000};
        fd_set fds;
        FD_ZERO(&fds); FD_SET(0, &fds);
        if (select(1, &fds, NULL, NULL, &tv) <= 0) return "";
        char s[4] = {0};
        read(0, s, 1);
        if (s[0] != '[') return "";
        tv.tv_usec = 50000; FD_SET(0, &fds);
        if (select(1, &fds, NULL, NULL, &tv) <= 0) return "";
        read(0, s + 1, 1);
        if (s[1] == 'A') return "UP";
        if (s[1] == 'B') return "DOWN";
        if (s[1] == '5') { char t; read(0, &t, 1); return "PGUP"; }
        if (s[1] == '6') { char t; read(0, &t, 1); return "PGDN"; }
        return "";
    }
    _lx_keybuf[0] = c; _lx_keybuf[1] = 0;
    return _lx_keybuf;
}

static char* lxTermsize(void) {
    static char buf[32];
    struct winsize w;
    ioctl(1, TIOCGWINSZ, &w);
    int c = w.ws_col > 0 ? w.ws_col : 80;
    int r = w.ws_row > 0 ? w.ws_row : 24;
    snprintf(buf, 32, "%d,%d", c, r);
    return buf;
}

static char* lxSleep(const char* ms) {
    usleep((unsigned int)atoi(ms) * 1000);
    return "";
}

static char _lx_pidlist[65536];
static char* lxListPids(void) {
    DIR* d = opendir("/proc");
    if (!d) return "";
    _lx_pidlist[0] = 0;
    int pos = 0;
    struct dirent* e;
    while ((e = readdir(d)) != NULL) {
        if (e->d_name[0] < '1' || e->d_name[0] > '9') continue;
        int ok = 1;
        for (int i = 1; e->d_name[i]; i++)
            if (e->d_name[i] < '0' || e->d_name[i] > '9') { ok = 0; break; }
        if (!ok) continue;
        int l = strlen(e->d_name);
        if (pos + l + 1 < 65534) {
            memcpy(_lx_pidlist + pos, e->d_name, l);
            pos += l;
            _lx_pidlist[pos++] = '\n';
        }
    }
    closedir(d);
    _lx_pidlist[pos] = 0;
    return _lx_pidlist;
}

#endif // __linux__
