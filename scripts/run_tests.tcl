#!/usr/bin/env tclsh
# =============================================================================
# run_tests.tcl
# -----------------------------------------------------------------------------
# Automation script for the UART Transmitter self-checking testbench suite.
#
# For every test listed in test_list.txt, this script:
#   1. Compiles the DUT + that testbench with Icarus Verilog (iverilog)
#   2. Runs the compiled simulation (vvp)
#   3. Saves the full console output to logs/<testname>_log.txt
#   4. Scans that log for the word "FAIL" and reports PASS/FAIL per test
#   5. Prints a final summary of all tests, and exits non-zero if any failed
#
# Usage:
#   tclsh run_tests.tcl
#
# Directory layout expected (relative to this script's location):
#   ../rtl/uart_tx.v
#   ../tb/<testname>.v           (also expects ../tb/uart_common.vh via `include)
#   ../scripts/test_list.txt
#   ../logs/                      (created if missing)
# =============================================================================

set SCRIPT_DIR   [file dirname [file normalize [info script]]]
set PROJECT_DIR  [file normalize [file join $SCRIPT_DIR ..]]
set RTL_DIR      [file join $PROJECT_DIR rtl]
set TB_DIR       [file join $PROJECT_DIR tb]
set LOG_DIR      [file join $PROJECT_DIR logs]
set TEST_LIST    [file join $SCRIPT_DIR test_list.txt]
set DUT_FILE     [file join $RTL_DIR uart_tx.v]

# ---- sanity checks ---------------------------------------------------------
if {![file exists $DUT_FILE]} {
    puts "ERROR: DUT file not found: $DUT_FILE"
    exit 1
}
if {![file exists $TEST_LIST]} {
    puts "ERROR: Test list not found: $TEST_LIST"
    exit 1
}
file mkdir $LOG_DIR

# ---- read test names --------------------------------------------------------
set fh [open $TEST_LIST r]
set raw_tests [split [read $fh] "\n"]
close $fh

set tests {}
foreach t $raw_tests {
    set t [string trim $t]
    if {$t ne ""} { lappend tests $t }
}

puts "============================================================"
puts " UART Transmitter - Automated Test Execution"
puts " DUT        : $DUT_FILE"
puts " Test count : [llength $tests]"
puts " Log dir    : $LOG_DIR"
puts "============================================================"
puts ""

# ---- run each test -----------------------------------------------------------
set results {}
set n_pass 0
set n_fail 0

foreach testname $tests {
    set tb_file  [file join $TB_DIR "${testname}.v"]
    set vvp_file [file join $TB_DIR "${testname}.vvp"]
    set log_file [file join $LOG_DIR "${testname}_log.txt"]

    if {![file exists $tb_file]} {
        puts "  $testname ... SKIPPED (testbench file not found: $tb_file)"
        lappend results [list $testname "SKIPPED"]
        incr n_fail
        continue
    }

    # --- Compile ---
    # Same Tcl `exec`-stderr caveat applies here: iverilog can print benign
    # warnings to stderr on a successful compile. So we judge success by
    # whether the output .vvp file was actually produced, not by the
    # catch/exit status of exec.
    file delete -force $vvp_file
    set compile_cmd [list iverilog -o $vvp_file -I $TB_DIR $DUT_FILE $tb_file]
    set compile_log ""
    if {[catch {set compile_log [exec {*}$compile_cmd 2>@1]} err]} {
        set compile_log $err
    }
    set compile_ok [file exists $vvp_file]

    if {!$compile_ok} {
        set fh [open $log_file w]
        puts $fh "===== COMPILE FAILED for $testname ====="
        puts $fh $compile_log
        close $fh
        puts "  $testname ... FAIL (compile error, see $log_file)"
        lappend results [list $testname "FAIL"]
        incr n_fail
        continue
    }

    # --- Run ---
    # NOTE: Tcl's `exec` treats ANY stderr output as an error even when the
    # child process exits 0 (vvp's VCD/$finish diagnostics go to stderr), so
    # we deliberately do NOT gate pass/fail on the exec/catch status here -
    # we rely solely on scanning the captured log text itself, which is
    # correct in both the normal-return and the caught-as-error cases below
    # since 2>@1 merges stdout+stderr into the same captured string either way.
    set run_log ""
    if {[catch {set run_log [exec vvp $vvp_file 2>@1]} err]} {
        set run_log $err
    }

    set fh [open $log_file w]
    puts $fh $run_log
    close $fh

    # --- Scan log for the word FAIL (per the assignment's required check),
    # using the authoritative RESULT: line rather than a bare substring
    # search - "TOTAL FAIL = 0" would otherwise falsely match "FAIL".
    set has_result_fail [expr {[string first "RESULT: FAIL" $run_log] != -1}]
    set has_result_pass [expr {[string first "RESULT: PASS" $run_log] != -1}]

    if {$has_result_pass && !$has_result_fail} {
        puts "  $testname ... PASS"
        lappend results [list $testname "PASS"]
        incr n_pass
    } else {
        puts "  $testname ... FAIL (see $log_file)"
        lappend results [list $testname "FAIL"]
        incr n_fail
    }
}

# ---- final summary -----------------------------------------------------------
puts ""
puts "============================================================"
puts " SUMMARY"
puts "============================================================"
foreach r $results {
    set nm     [lindex $r 0]
    set status [lindex $r 1]
    puts [format "  %-28s %s" "${nm}..." $status]
}
puts "------------------------------------------------------------"
puts "  TOTAL: [llength $tests]   PASS: $n_pass   FAIL/SKIPPED: $n_fail"
puts "============================================================"

if {$n_fail > 0} {
    exit 1
} else {
    exit 0
}
