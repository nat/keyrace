// NOTE: This client no longer works. Run the native mac client instead!
//
// gcc keyrace.c -o keyrace -framework ApplicationServices -framework Carbon -Wall -g
//
// To start tracking, run as: keyrace <username> <team>
// To print leaderboard, run: keyrace <team>
//
// Just use "default" as your team if you don't have one.

#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <ApplicationServices/ApplicationServices.h>
#include <Carbon/Carbon.h>
#include <string.h>
#include <sys/stat.h>

const char KEYRACE_HOST[] = "159.89.136.69";
const char TMPFILE[] = "/tmp/keyrace.tmp";

char *username;
char *team;
int keycount = 0;
int last_day = -1;
int last_min = -1;

void update_savefile(int kc)
{
    FILE *f;
    f = fopen(TMPFILE, "w");
    fprintf(f, "%d\n", kc);
    fclose(f);
}

int load_savefile(void)
{
    struct stat stat_buffer;
    int saved_keycount;
    FILE *f;

    f = fopen(TMPFILE, "r");
    if (f == NULL)
        return 0;
    fscanf(f, "%d", &saved_keycount);

    if (stat(TMPFILE, &stat_buffer) != 0)
        return 0;

    struct tm mtime = *localtime(&stat_buffer.st_mtime);
    last_day = mtime.tm_yday;

    fclose(f);

    return saved_keycount;
}

void upload_count(char *name, int count)
{
    char s[1024];
    snprintf(s, 1024, "curl \"http://%s/count?team=%s&name=%s&count=%d\" 2> /dev/null > /dev/null", KEYRACE_HOST, team, name, count);
    system(s);
}

// invoked on every keypress
CGEventRef CGEventCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon)
{
    time_t t = time(NULL);

    if (type != kCGEventKeyDown && type != kCGEventFlagsChanged && type != kCGEventKeyUp)
    {
        return event;
    }

    struct tm tm = *localtime(&t);

    // Reset to 0 at midnight
    if (last_day != tm.tm_yday)
    {
        last_day = tm.tm_yday;
        keycount = 0;
    }

    keycount++;

    // Upload every minute
    if (last_min != tm.tm_min)
    {
        last_min = tm.tm_min;

        upload_count(username, keycount);
    }

    update_savefile(keycount);

    return event;
}

void strclean(char *src)
{
    char *p = src;
    while (*src)
    {
        if (isalnum(*src))
            *p++ = *src;
        src++;
    }
    *p = '\0';
}

void run_loop(void)
{
    // Create an event tap to retrieve keypresses.
    CGEventMask eventMask = (CGEventMaskBit(kCGEventKeyDown) | CGEventMaskBit(kCGEventFlagsChanged));
    CFMachPortRef eventTap = CGEventTapCreate(
        kCGSessionEventTap, kCGHeadInsertEventTap, 0, eventMask, CGEventCallback, NULL);

    // Exit the program if unable to create the event tap.
    if (!eventTap)
    {
        fprintf(stderr, "ERROR: Unable to create event tap.\n");
        exit(1);
    }

    // Create a run loop source and add enable the event tap.
    CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
    CGEventTapEnable(eventTap, true);

    CFRunLoopRun();
}

int main(int argc, char **argv)
{

    if (argc < 2 || argc > 3 || !strcmp (argv[1], "--help"))
    {
        printf("Try: \n");
        printf("    %s <team> <username> -- to start logging\n", argv[0]);
        printf("    %s <team> -- to get the tracking\n", argv[0]);
        printf("Just use \"default\" as your team if you don't have one.\n");
        return 1;
    }

    if (argc == 2)
    {
        char cmd[1024];
        snprintf(cmd, 1024, "curl http://%s/?team=%s", KEYRACE_HOST, argv[1]);
        system(cmd);
        return 0;
    }

    username = argv[2];
    team = argv[1];
    strclean(username);
    strclean(team);

    keycount = load_savefile();

    printf("Starting counting keystrokes in the background.\n");

    int pid = fork();
    if (pid == 0)
    { // child
        setpgid(0, 0);
        run_loop();
    }
}