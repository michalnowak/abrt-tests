-include ../../config.mak

bin_PROGRAMS = abrt-cli

CLI_C =
CLI_C += abrt-cli.c

BUILTIN_C =
BUILTIN_C += list.c
BUILTIN_C += rm.c
BUILTIN_C += report.c

abrt_cli_SOURCES = $(CLI_C) $(BUILTIN_C) builtin-cmd.h

abrt_cli_CFLAGS = \
	-I$(srcdir)/../include \
	-I$(srcdir)/../lib \
	$(LIBREPORT_CFLAGS) \
	-Wwrite-strings -Werror

abrt_cli_LDADD = \
    $(LIBREPORT_LIBS) \
    ../lib/libabrt.la

DEFS = -DLOCALEDIR=\"$(localedir)\" @DEFS@
