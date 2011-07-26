/*
    Copyright (C) 2011  ABRT Team
    Copyright (C) 2011  RedHat inc.

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program; if not, write to the Free Software Foundation, Inc.,
    51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
*/

#include "abrtlib.h"
#include "builtin-cmd.h"

#define USAGE_OPTS_WIDTH 12
#define USAGE_GAP         2

/* TODO: add --pager(default) and --no-pager */

const char abrt_cli_usage_string[] =
    "abrt-cli [--version] <command> [<args>]";

struct cmd_struct {
    const char *cmd;
    int (*fn)(int, const char **);
    const char *help;
};

static void list_cmds_help(const struct cmd_struct *commands)
{
    for (const struct cmd_struct *p = commands; p->cmd; ++p)
    {
        size_t pos;
        int pad;

        pos = fprintf(stderr, "    ");
        pos += fprintf(stderr, "%s", p->cmd);

        if (pos <= USAGE_OPTS_WIDTH)
            pad = USAGE_OPTS_WIDTH - pos;
        else
        {
            fputc('\n', stderr);
            pad = USAGE_OPTS_WIDTH;
        }

        fprintf(stderr, "%*s%s\n", pad + USAGE_GAP, "", p->help);
    }
}

static void handle_internal_options(int *argc, const char ***argv)
{
    while (*argc > 0)
    {
        const char *cmd = (*argv)[0];
        if (cmd[0] != '-')
            break;

        if (strcmp(cmd, "--version") == 0)
        {
            puts(PACKAGE_VERSION);
            exit(0);
        }
#if 0
        else if (prefixcmp(cmd, "--base-dir=") == 0)
            D_list = g_list_append(D_list, xstrdup(cmd + strlen("--base-dir=")));
        else if (prefixcmp(cmd, "--list-events") == 0)
        {
            const char *pfx = cmd + strlen("--list-events");
            if (pfx && *pfx)
                pfx += 1; /* skip '=' */

            char *events = list_possible_events(NULL, dump_dir_name, pfx);
            if (!events)
                exit(1); /* error msg is already logged */

            fputs(events, stdout);
            free(events);

            exit(0);
        }
#endif
        else
            error_msg_and_die("usage: %s", abrt_cli_usage_string);

        (*argv)++;
        (*argc)--;
    }
}

static void handle_internal_command(int argc, const char **argv,
                                    const struct cmd_struct *commands)
{
    const char *cmd = argv[0];

    for (const struct cmd_struct *p = commands; p->cmd; ++p)
    {
        if (strcmp(p->cmd, cmd))
            continue;

        exit(p->fn(argc, argv));
    }
}

int main(int argc, const char **argv)
{
    abrt_init((char **)argv);

    setlocale(LC_ALL, "");
#if ENABLE_NLS
    bindtextdomain(PACKAGE, LOCALEDIR);
    textdomain(PACKAGE);
#endif

    argv++;
    argc--;

    const struct cmd_struct commands[] = {
        {"list", cmd_list, _("List not yet reported problems")},
        {"rm", cmd_rm, _("Remove files from problem directory")},
        {"report", cmd_report, _("Analyze and report problem data in problem directory")},
        {"info", cmd_info, _("Print information about DUMP_DIR")},
        {NULL, NULL, NULL}
    };

    handle_internal_options(&argc, &argv);
    if (argc > 0)
        handle_internal_command(argc, argv, commands);

    /* user didn't specify command; print out help */
    printf("%s\n\n", abrt_cli_usage_string);
    list_cmds_help(commands);
    printf("\n%s\n", _("See 'abrt-cli <command> -h' for more information"));

    return 0;
}
