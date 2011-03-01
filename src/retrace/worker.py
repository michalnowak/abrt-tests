#!/usr/bin/python

import sys
import time
from retrace import *

LOG = None

def retrace_run(errorcode, cmd):
    "Runs cmd using subprocess.Popen and kills script with errorcode on failure"
    try:
        process = Popen(cmd, stdout=PIPE, stderr=STDOUT)
        process.wait()
        output = process.stdout.read()
        process.stdout.close()
    except Exception as ex:
        process = None
        output = "An unhandled exception occured: %s" % ex

    if not process or process.returncode != 0:
        LOG.write("Error %d:\n=== OUTPUT ===\n%s\n" % (errorcode, output))
        LOG.close()
        sys.exit(errorcode)

    return output

if __name__ == "__main__":
    starttime = time.time()

    if len(sys.argv) != 2:
        sys.stderr.write("Usage: %s task_id\n" % sys.argv[0])
        sys.exit(11)

    taskid = sys.argv[1]
    try:
        int(taskid)
    except:
        sys.stderr.write("Task ID may only contain digits.\n")
        sys.exit(12)

    savedir = workdir = "%s/%s" % (CONFIG["SaveDir"], taskid)

    if CONFIG["UseWorkDir"]:
        workdir = "%s/%s" % (CONFIG["WorkDir"], taskid)

    if not os.path.isdir(savedir):
        sys.stderr.write("Task '%s' does not exist.\n" % workdir)
        sys.exit(13)

    try:
        LOG = logger(taskid)
    except Exception as ex:
        sys.stderr.write("Unable to start logging for task '%s': %s.\n" % (taskid, ex))
        sys.exit(14)

    # check the crash directory for required files
    for required_file in REQUIRED_FILES:
        if not os.path.isfile("%s/crash/%s" % (savedir, required_file)):
            LOG.write("Crash directory does not contain required file '%s'.\n" % required_file)
            LOG.close()
            sys.exit(15)

    # read architecture file
    try:
        arch_file = open("%s/crash/architecture" % savedir, "r")
        arch = repoarch = arch_file.read()
        arch_file.close()
    except Exception as ex:
        LOG.write("Unable to read architecture from 'architecture' file: %s.\n" % ex)
        LOG.close()
        sys.exit(16)

    # required hack for public repos
    if arch == "i686":
        repoarch = "i386"

    # read release, distribution and version from release file
    try:
        release_file = open("%s/crash/release" % savedir, "r")
        release = release_file.read()
        release_file.close()
    except Exception as ex:
        LOG.write("Unable to read distribution and version from 'release' file: %s.\n" % ex)
        LOG.close()
        sys.exit(17)

    version = distribution = None
    for distro in RELEASE_PARSERS.keys():
        match = RELEASE_PARSERS[distro].match(release)
        if match:
            version = match.group(1)
            distribution = distro
            break

    if not version or not distribution:
        LOG.write("Release '%s' is not supported.\n" % release)
        LOG.close()
        sys.exit(18)

    # read package file
    try:
        package_file = open("%s/crash/package" % savedir, "r")
        crash_package = package_file.read()
        package_file.close()
    except Exception as ex:
        LOG.write("Unable to read crash package from 'package' file: %s.\n" % ex)
        LOG.close()
        sys.exit(19)

    # read required packages from coredump
    packages = "%s.%s" % (crash_package, arch)
    try:
        # ToDo: deal with not found build-ids
        pipe = Popen(["/usr/share/abrt-retrace/coredump2packages.py", "%s/crash/coredump" % savedir, "--repos=retrace-%s-%s-%s*" % (distribution, version, arch)], stdout=PIPE).stdout
        section = 0
        crash_package_or_component = None
        for line in pipe.readlines():
            if line == "\n":
                section += 1
                continue
            elif 0 == section:
                crash_package_or_component = line.strip()
            elif 1 == section:
                packages += " %s" % line.rstrip("\n")
            elif 2 == section:
                # Missing build ids
                pass
        pipe.close()
    except Exception as ex:
        LOG.write("Unable to obtain packages from 'coredump' file: %s.\n" % ex)
        LOG.close()
        sys.exit(20)

    # create mock config file
    try:
        mockcfg = open("%s/mock.cfg" % savedir, "w")
        mockcfg.write("config_opts['root'] = 'chroot'\n")
        mockcfg.write("config_opts['target_arch'] = '%s'\n" % arch)
        mockcfg.write("config_opts['chroot_setup_cmd'] = 'install %s shadow-utils abrt-addon-ccpp gdb'\n" % packages)
        mockcfg.write("config_opts['basedir'] = '%s'\n" % workdir)
        mockcfg.write("config_opts['plugin_conf']['ccache_enable'] = False\n")
        mockcfg.write("config_opts['plugin_conf']['yum_cache_enable'] = False\n")
        mockcfg.write("config_opts['plugin_conf']['root_cache_enable'] = False\n")
        mockcfg.write("\n")
        mockcfg.write("config_opts['yum.conf'] = \"\"\"\n")
        mockcfg.write("[main]\n")
        mockcfg.write("cachedir=/var/cache/yum\n")
        mockcfg.write("debuglevel=1\n")
        mockcfg.write("reposdir=/dev/null\n")
        mockcfg.write("logfile=/var/log/yum.log\n")
        mockcfg.write("retries=20\n")
        mockcfg.write("obsoletes=1\n")
        mockcfg.write("gpgcheck=0\n")
        mockcfg.write("assumeyes=1\n")
        mockcfg.write("syslog_ident=mock\n")
        mockcfg.write("syslog_device=\n")
        mockcfg.write("\n")
        mockcfg.write("#repos\n")
        mockcfg.write("\n")
        mockcfg.write("[fedora]\n")
        mockcfg.write("name=fedora\n")
        mockcfg.write("baseurl=file://%s/%s-%s-%s/\n" % (CONFIG["RepoDir"], distribution, version, arch))
        mockcfg.write("failovermethod=priority\n")
        mockcfg.write("\n")
        mockcfg.write("[fedora-debuginfo]\n")
        mockcfg.write("name=fedora-debuginfo\n")
        mockcfg.write("baseurl=file://%s/%s-%s-%s-debuginfo/\n" % (CONFIG["RepoDir"], distribution, version, arch))
        mockcfg.write("failovermethod=priority\n")
        mockcfg.write("\n")
        mockcfg.write("[updates]\n")
        mockcfg.write("name=updates\n")
        mockcfg.write("baseurl=file://%s/%s-%s-%s-updates/\n" % (CONFIG["RepoDir"], distribution, version, arch))
        mockcfg.write("failovermethod=priority\n")
        mockcfg.write("\n")
        mockcfg.write("[updates-debuginfo]\n")
        mockcfg.write("name=updates-debuginfo\n")
        mockcfg.write("baseurl=file://%s/%s-%s-%s-updates-debuginfo/\n" % (CONFIG["RepoDir"], distribution, version, arch))
        mockcfg.write("failovermethod=priority\n")
        mockcfg.write("\n")
        mockcfg.write("[updates-testing]\n")
        mockcfg.write("name=updates-testing\n")
        mockcfg.write("baseurl=file://%s/%s-%s-%s-updates-testing/\n" % (CONFIG["RepoDir"], distribution, version, arch))
        mockcfg.write("failovermethod=priority\n")
        mockcfg.write("\n")
        mockcfg.write("[updates-testing-debuginfo]\n")
        mockcfg.write("name=updates-testing-debuginfo\n")
        mockcfg.write("baseurl=file://%s/%s-%s-%s-updates-testing-debuginfo/\n" % (CONFIG["RepoDir"], distribution, version, arch))
        mockcfg.write("failovermethod=priority\n")
        mockcfg.write("\n")
        # custom ABRT repo with ABRT 2.0 binaries - obsolete after release of ABRT 2.0
        mockcfg.write("[abrt]\n")
        mockcfg.write("name=abrt\n")
        mockcfg.write("baseurl=http://repos.fedorapeople.org/repos/mtoman/abrt20/%s-%s/%s/\n" % (distribution, version, repoarch))
        mockcfg.write("failovermethod=priority\n")
        mockcfg.write("\n")
        mockcfg.write("\"\"\"\n")
        mockcfg.close()
    except Exception as ex:
        LOG.write("Unable to create mock config file: %s.\n" % ex)
        LOG.close()
        sys.exit(21)

    # get count of tasks running before starting
    prerunning = len(get_active_tasks()) - 1

    # run retrace
    mockr = "../../%s/mock" % savedir

    LOG.write("Initializing virtual root... ")

    retrace_run(25, ["mock", "init", "-r", mockr])
    retrace_run(26, ["mock", "-r", mockr, "--copyin", "%s/crash" % savedir, "/var/spool/abrt/crash"])
    retrace_run(27, ["touch", "%s/chroot/root/var/spool/abrt/crash/time" % workdir])

    LOG.write("OK\n")

    try:
        rootfile = open("%s/chroot/result/root.log" % workdir, "r")
        rootlog = rootfile.read()
        rootfile.close()
    except Exception as ex:
        LOG.write("Error reading root log: %s.\n" % ex)
        rootlog = "Not found"

    # generate backtrace
    LOG.write("Generating backtrace... ")

    retrace_run(28, ["mock", "shell", "-r", mockr, "--", "/usr/bin/abrt-action-generate-backtrace", "-d", "/var/spool/abrt/crash/"])
    retrace_run(29, ["mock", "-r", mockr, "--copyout", "/var/spool/abrt/crash/backtrace", savedir])
    retrace_run(30, ["chmod", "a+r", "%s/backtrace" % savedir])

    LOG.write("OK\n")

    chroot_size = dir_size("%s/chroot/root" % workdir)

    # clean up temporary data
    LOG.write("Cleaning up... ")

    retrace_run(31, ["mock", "-r", mockr, "--scrub=all"])
    retrace_run(32, ["rm", "-rf", "%s/mock.cfg" % savedir, "%s/crash" % savedir])

    # ignore error: workdir = savedir => workdir is not empty
    if CONFIG["UseWorkDir"]:
        try:
            os.rmdir(workdir)
        except:
            pass

    LOG.write("OK\n")

    # save crash statistics
    LOG.write("Saving crash statistics... ")

    duration = int(time.time() - starttime)

    package_match = PACKAGE_PARSER.match(crash_package)
    if not package_match:
        package = crash_package
        version = "unknown"
        release = "unknown"
    else:
        package = package_match.group(1)
        version = package_match.group(2)
        release = package_match.group(4)

    crashstats = {
      "taskid": int(taskid),
      "package": package,
      "version": version,
      "release": release,
      "arch": arch,
      "starttime": int(starttime),
      "duration": duration,
      "prerunning": prerunning,
      "postrunning": len(get_active_tasks()) - 1,
      "chrootsize": chroot_size
    }

    if not init_crashstats_db() or not save_crashstats(crashstats):
        LOG.write("Error: %s\n" % crashstats)
    else:
        LOG.write("OK\n")

    # publish bactkrace and log
    LOG.write("Finishing task... ")

    try:
        os.rename("%s/backtrace" % savedir, "%s/retrace_backtrace" % savedir)
    except Exception as ex:
        LOG.write("Error: %s\n" % ex)
        LOG.close()
        sys.exit(35)

    LOG.write("OK\n")
    LOG.write("Retrace took %d seconds.\n" % duration)

    LOG.write("\n=== ROOT LOG ===\n%s\n" % rootlog)
    LOG.close()