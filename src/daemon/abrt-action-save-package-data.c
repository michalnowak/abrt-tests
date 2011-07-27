/*
    Copyright (C) 2009  Zdenek Prikryl (zprikryl@redhat.com)
    Copyright (C) 2009  RedHat inc.

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
#include <fnmatch.h>
#include "abrtlib.h"
#include "rpm.h"

static bool   settings_bOpenGPGCheck = false;
static GList *settings_setOpenGPGPublicKeys = NULL;
static GList *settings_setBlackListedPkgs = NULL;
static GList *settings_setBlackListedPaths = NULL;
static bool   settings_bProcessUnpackaged = false;

static GList *parse_list(const char* list)
{
    struct strbuf *item = strbuf_new();
    GList *l = NULL;

    char *trim_item = NULL;

    for (unsigned ii = 0; list[ii]; ii++)
    {
        if (list[ii] == ',')
        {
            trim_item = strtrim(item->buf);
            l = g_list_append(l, xstrdup(trim_item));
            strbuf_clear(item);
        }
        else
            strbuf_append_char(item, list[ii]);
    }

    if (item->len > 0)
    {
        trim_item = strtrim(item->buf);
        l = g_list_append(l, xstrdup(trim_item));
    }

    strbuf_free(item);

    return l;
}

static void ParseCommon(map_string_h *settings, const char *conf_filename)
{
    char *value;

    value = g_hash_table_lookup(settings, "OpenGPGCheck");
    if (value)
    {
        settings_bOpenGPGCheck = string_to_bool(value);
        g_hash_table_remove(settings, "OpenGPGCheck");
    }

    value = g_hash_table_lookup(settings, "BlackList");
    if (value)
    {
        settings_setBlackListedPkgs = parse_list(value);
        g_hash_table_remove(settings, "BlackList");
    }

    value = g_hash_table_lookup(settings, "BlackListedPaths");
    if (value)
    {
        settings_setBlackListedPaths = parse_list(value);
        g_hash_table_remove(settings, "BlackListedPaths");
    }

    value = g_hash_table_lookup(settings, "ProcessUnpackaged");
    if (value)
    {
        settings_bProcessUnpackaged = string_to_bool(value);
        g_hash_table_remove(settings, "ProcessUnpackaged");
    }

    GHashTableIter iter;
    char *name;
    /*char *value; - already declared */
    g_hash_table_iter_init(&iter, settings);
    while (g_hash_table_iter_next(&iter, (void**)&name, (void**)&value))
    {
        error_msg("Unrecognized variable '%s' in '%s'", name, conf_filename);
    }
}

static void load_gpg_keys(void)
{
    FILE *fp = fopen(CONF_DIR"/gpg_keys", "r");
    if (fp)
    {
        /* every line is one key
         * FIXME: make it more robust, it doesn't handle comments
         */
        char *line;
        while ((line = xmalloc_fgetline(fp)) != NULL)
        {
            if (line[0] == '/') // probably the beginning of a path, so let's handle it as a key
                settings_setOpenGPGPublicKeys = g_list_append(settings_setOpenGPGPublicKeys, line);
            else
                free(line);
        }
        fclose(fp);
    }
}

static int load_conf(const char *conf_filename)
{
    map_string_h *settings = new_map_string();
    if (!load_conf_file(conf_filename, settings, /*skip key w/o values:*/ false))
        error_msg("Can't open '%s'", conf_filename);

    ParseCommon(settings, conf_filename);
    free_map_string(settings);

    load_gpg_keys();

    return 0;
}

/**
 * Returns the first full path argument in the command line or NULL.
 * Skips options (params of the form "-XXX").
 * Returns malloc'ed string.
 * NB: the cmdline is delimited by (single, not multiple) spaces, not tabs!
 * "abc def\t123" means there are two params: "abc", "def\t123".
 * "abc  def" means there are three params: "abc", "", "def".
 */
static char *get_argv1_if_full_path(const char* cmdline)
{
    const char *argv1 = strchr(cmdline, ' ');
    while (argv1 != NULL)
    {
        /* we found space in cmdline, so it might contain
         * path to some script like:
         * /usr/bin/python [-XXX] /usr/bin/system-control-network
         */
        argv1++; /* skip the space */
        if (*argv1 != '-')
            break;
        /* looks like -XXX in "perl -XXX /usr/bin/script.pl", skipping */
        argv1 = strchr(argv1, ' ');
    }

    /* if the string following the space doesn't start
     * with '/', it is not a full path to script
     * and we can't use it to determine the package name
     */
    if (argv1 == NULL || *argv1 != '/')
        return NULL;

    /* good, it has "/foo/bar" form, return it */
    int len = strchrnul(argv1, ' ') - argv1;
    return xstrndup(argv1, len);
}

static bool is_path_blacklisted(const char *path)
{
    GList *li;
    for (li = settings_setBlackListedPaths; li != NULL; li = g_list_next(li))
    {
        if (fnmatch((char*)li->data, path, /*flags:*/ 0) == 0)
        {
            return true;
        }
    }
    return false;
}

static int SavePackageDescriptionToDebugDump(const char *dump_dir_name)
{
    struct dump_dir *dd = dd_opendir(dump_dir_name, /*flags:*/ 0);
    if (!dd)
        return 1;

    char *cmdline = NULL;
    char *executable = NULL;
    char *script_name = NULL; /* only if "interpreter /path/to/script" */
    char *package_short_name = NULL;
    char *package_full_name = NULL;
    char *component = NULL;
    int error = 1;
    /* note: "goto ret" statements below free all the above variables,
     * but they don't dd_close(dd) */

    char *analyzer = dd_load_text(dd, FILENAME_ANALYZER);
    bool kernel = (strcmp(analyzer, "Kerneloops") == 0);
    free(analyzer);
    if (kernel)
    {
        package_full_name = xstrdup("kernel");
        component = xstrdup("kernel");
    }
    else
    {
        char *remote_str = dd_load_text_ext(dd, FILENAME_REMOTE, DD_FAIL_QUIETLY_ENOENT);
        bool remote = string_to_bool(remote_str);
        free(remote_str);

        cmdline = dd_load_text(dd, FILENAME_CMDLINE);
        executable = dd_load_text(dd, FILENAME_EXECUTABLE);

        /* Close dd while we query package database. It can take some time,
         * don't want to keep dd locked longer than necessary */
        dd_close(dd);

        if (is_path_blacklisted(executable))
        {
            log("Blacklisted executable '%s'", executable);
            goto ret; /* return 1 (failure) */
        }

        package_full_name = rpm_get_package_nvr(executable);
        if (!package_full_name)
        {
            if (settings_bProcessUnpackaged || remote)
            {
                VERB2 log("Crash in unpackaged executable '%s', proceeding without packaging information", executable);
                dd = dd_opendir(dump_dir_name, /*flags:*/ 0);
                if (!dd)
                    goto ret; /* return 1 (failure) */
                dd_save_text(dd, FILENAME_PACKAGE, "");
                dd_save_text(dd, FILENAME_COMPONENT, "");
                goto ret0; /* no error */
            }
            log("Executable '%s' doesn't belong to any package", executable);
            goto ret; /* return 1 (failure) */
        }

        /* Check well-known interpreter names */
        {
            const char *basename = strrchr(executable, '/');
            if (basename) basename++; else basename = executable;

            /* Add more interpreters as needed */
            if (strcmp(basename, "python") == 0
             || strcmp(basename, "perl") == 0
            ) {
// TODO: we don't verify that python executable is not modified
// or that python package is properly signed
// (see CheckFingerprint/CheckHash below)
                /* Try to find package for the script by looking at argv[1].
                 * This will work only if the cmdline contains the whole path.
                 * Example: python /usr/bin/system-control-network
                 */
                char *script_pkg = NULL;
                char *script_name = get_argv1_if_full_path(cmdline);
                if (script_name)
                {
                    script_pkg = rpm_get_package_nvr(script_name);
                    if (script_pkg)
                    {
                        /* There is a well-formed script name in argv[1],
                         * and it does belong to some package.
                         * Replace interpreter's package_full_name and executable
                         * with data pertaining to the script.
                         */
                        free(package_full_name);
                        package_full_name = script_pkg;
                        executable = script_name;
                        /* executable has changed, check it again */
                        if (is_path_blacklisted(executable))
                        {
                            log("Blacklisted executable '%s'", executable);
                            goto ret; /* return 1 (failure) */
                        }
                    }
                }
                if (!script_pkg && !settings_bProcessUnpackaged && !remote)
                {
                    log("Interpreter crashed, but no packaged script detected: '%s'", cmdline);
                    goto ret; /* return 1 (failure) */
                }
            }
        }

        package_short_name = get_package_name_from_NVR_or_NULL(package_full_name);
        VERB2 log("Package:'%s' short:'%s'", package_full_name, package_short_name);

        GList *li;

        for (li = settings_setBlackListedPkgs; li != NULL; li = g_list_next(li))
        {
            if (strcmp((char*)li->data, package_short_name) == 0)
            {
                log("Blacklisted package '%s'", package_short_name);
                goto ret; /* return 1 (failure) */
            }
        }

        if (settings_bOpenGPGCheck && !remote)
        {
            if (!rpm_chk_fingerprint(package_short_name))
            {
                log("Package '%s' isn't signed with proper key", package_short_name);
                goto ret; /* return 1 (failure) */
            }
            /* We used to also check the integrity of the executable here:
             *  if (!CheckHash(package_short_name.c_str(), executable)) BOOM();
             * Checking the MD5 sum requires to run prelink to "un-prelink" the
             * binaries - this is considered potential security risk so we don't
             * do it now, until we find some non-intrusive way.
             */
        }

        component = rpm_get_component(executable);

        dd = dd_opendir(dump_dir_name, /*flags:*/ 0);
        if (!dd)
            goto ret; /* return 1 (failure) */
    }

    if (package_full_name)
    {
        dd_save_text(dd, FILENAME_PACKAGE, package_full_name);
    }
    if (component)
    {
        dd_save_text(dd, FILENAME_COMPONENT, component);
    }

    dd_close(dd);

 ret0:
    error = 0;
 ret:
    free(cmdline);
    free(executable);
    free(script_name);
    free(package_short_name);
    free(package_full_name);
    free(component);

    return error;
}

int main(int argc, char **argv)
{
    abrt_init(argv);

    const char *dump_dir_name = ".";
    const char *conf_filename = CONF_DIR"/abrt-action-save-package-data.conf";

    /* Can't keep these strings/structs static: _() doesn't support that */
    const char *program_usage_string = _(
        "\b [-v] [-c CONFFILE] -d DIR\n"
        "\n"
        "Query package database and save package and component name"
    );
    enum {
        OPT_v = 1 << 0,
        OPT_d = 1 << 1,
        OPT_c = 1 << 2,
    };
    /* Keep enum above and order of options below in sync! */
    struct options program_options[] = {
        OPT__VERBOSE(&g_verbose),
        OPT_STRING('d', NULL, &dump_dir_name, "DIR"     , _("Dump directory")),
        OPT_STRING('c', NULL, &conf_filename, "CONFFILE", _("Configuration file")),
        OPT_END()
    };
    /*unsigned opts =*/ parse_opts(argc, argv, program_options, program_usage_string);

    export_abrt_envvars(0);

    VERB1 log("Loading settings");
    if (load_conf(conf_filename) != 0)
        return 1; /* syntax error (logged already by load_conf) */

    VERB1 log("Initializing rpm library");
    rpm_init();

    GList *li;
    for (li = settings_setOpenGPGPublicKeys; li != NULL; li = g_list_next(li))
    {
        VERB1 log("Loading GPG key '%s'", (char*)li->data);
        rpm_load_gpgkey((char*)li->data);
    }

    return SavePackageDescriptionToDebugDump(dump_dir_name);
    /* can call rpm_destroy but do we really need to bother? we are exiting! */
}
