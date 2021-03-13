# no eggdrop - tcl only debug
#package require md5
if {$tcl_interactive == 1} {
	if {![info exists __debug_strip]} { set __debug_strip 1 }
	if {![info exists __debug_botonchan]} { set __debug_botonchan 1 }
	puts "*** DEBUG MODE ***"
	puts "TCL: $tcl_version ([info patchlevel])"
	proc setudef {type var} {}
	proc bind {class flags str proc} { if {$class eq "cron" || $class eq "time"} { $proc 0 0 0 0 0 } }
	proc putlog {text} { puts $text }
	proc putdcc {idx text} { puts $text }
	proc puthelp {text} {
		if {$::__debug_strip} {
			puts [stripcodes "" $text]
		} else {
			puts [string map {"\002" "B" "\003" "C" "\017" "P" "\026" "R" "\037" "U" "\035" "I"} $text]
		}
	}
	proc channel {what chan var} { return 1 }
	proc channels {} { return "chan" }
	proc botonchan {chan} { return $::__debug_botonchan }
	proc unixtime {} { return [clock seconds] }
	proc rand {limit} { return [expr {int(rand() * $limit)}] }
	proc strftime {format {ticks ""}} { return [clock format [expr {$ticks eq "" ? [unixtime] : $ticks}] -format [string map {"%-" "%"} $format]] }
	proc stripcodes {what text} { return [regsub -all {\003(\d{1,2}(,\d{1,2})?)?} [string map {"\002" "" "\017" "" "\026" "" "\037" "" "\035" "" "\t" " "} $text] ""] }
	proc matchattr {hand flags chan} { return 0 }
	proc timer {delay code} { return "timer" }
	proc utimer {delay code} { return "utimer" }
	proc killtimer {timer} {}
	proc killutimer {timer} {}
	#catch { rename md5 "" }
	#proc md5 {text} { package require md5 ; return [string tolower [md5::md5 -hex $text]] }
	proc sha1 {text} { return "-" }

	proc event {proc args} { return [$proc "nick" "host" "hand" "chan" [join $args]] }
	proc pevent {proc args} { return [$proc "nick" "host" "hand" [join $args]] }
	proc dcc {proc args} { return [$proc "hand" 0 [join $args]] }

	proc __strip_codes {text} { return [regsub -nocase -all {\003(?:\d{1,2}(?:,\d{1,2})?)?|\002|\017|\026|\037|\007|\035|\036|\021|\004(?:[0-9a-f]{6}(?:,[0-9a-f]{6})?)?} $text ""] }
	proc __fix_args {text} { return [string trim [regsub -all {\s+} $text]] }
	proc __get_arg {text {idx 0}} { return [lindex [split $text] $idx] }
	proc __get_str {text {first 1} {last "end"}} { return [join [lrange [split $text] $first $last]] }

	set nick-len 15
	set version 1080000

	return
}
