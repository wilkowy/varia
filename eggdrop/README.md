# eggdrop
My eggdrop tweaks and fixes.

- tclhash_1.6.20_fix_tcl_8.5.x.c.diff - fix `tclhash.c` for TCL 8.5 (Eggdrop 1.6.20)
- eggdrop_1.6.20_handlen15.h.diff - increases HANDLEN from 9 to 15 in `eggdrop.h` (Eggdrop 1.6.20)
######
- eggdrop_1.6.21_handlen15.h.diff - increases HANDLEN from 9 to 15 in `eggdrop.h` (Eggdrop 1.6.21)
- tcl_1.6.21_fix_async_events.c.diff - fix `tcl.c` async timers (Eggdrop 1.6.21)
######
- core_1.9.0-1.help.diff - fix `core.help` formatting issue (Eggdrop 1.9.0 & 1.9.1)
######
- botcmd_1.9.2_nossl.c.diff - fix `botcmd.c` compilation error for when openssl is not present (Eggdrop 1.9.2)
- dcc_1.9.2_nossl.c.diff - fix `dcc.c` compilation error for when openssl is not present (Eggdrop 1.9.2)
- tclserv_1.9.2_nossl.c.diff - fix `tclserv.c` compilation error for when openssl is not present (Eggdrop 1.9.2)
######
- gseen.mod/slang_gseen_commands.c.diff - show year value in channel reply plus minor hardcode-fix in `slang_gseen_commands.c` (gseen.mod 1.1.1 dev3 & 1.2.0)
- stats.mod/msgcmds.c.diff - fix `msgcmds.c` to detect `https://` links and not prefix them with `http://` (stats.mod 1.3.3)
- stats.mod/stats.help.diff - fix `stats.help` formatting (stats.mod 1.3.3)
