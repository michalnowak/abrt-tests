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

/* TODO npajkovs:
 *   add -n, --dry-run
 *   add -q, --quite
 */

int cmd_rm(int argc, const char **argv)
{
    const char *program_usage_string = _(
        "\b rm [options] [<dump-dir>]..."
        );

    struct options program_options[] = {
        OPT__VERBOSE(&g_verbose),
        OPT_END()
    };

    parse_opts(argc, (char **)argv, program_options, program_usage_string);
    if (optind < argc)
    {
        int status;
        while (optind < argc)
        {
            const char *rm_dir = argv[optind++];
            status = delete_dump_dir_possibly_using_abrtd(rm_dir);
            if (!status)
                log("rm '%s'", rm_dir);
        }
    }

    return 0;
}
