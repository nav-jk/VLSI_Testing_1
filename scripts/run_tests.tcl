set SCRIPT_DIR   [file dirname [file normalize [info script]]]
set PROJECT_DIR  [file normalize [file join $SCRIPT_DIR ..]]
set RTL_DIR      [file join $PROJECT_DIR rtl]
set TB_DIR       [file join $PROJECT_DIR tb]
set LOG_DIR      [file join $PROJECT_DIR logs]
set WAVE_DIR     [file join $PROJECT_DIR waveforms]
set TEST_LIST    [file join $SCRIPT_DIR test_list.txt]
set DUT_FILE     [file join $RTL_DIR uart_tx.v]

if {![file exists $DUT_FILE]} {
    puts "ERROR: DUT file not found: $DUT_FILE"
    exit 1
}
if {![file exists $TEST_LIST]} {
    puts "ERROR: Test list not found: $TEST_LIST"
    exit 1
}
file mkdir $LOG_DIR
file mkdir $WAVE_DIR

set fh [open $TEST_LIST r]
set raw_tests [split [read $fh] "\n"]
close $fh

set tests {}
foreach t $raw_tests {
    set t [string trim $t]
    if {$t ne ""} { lappend tests $t }
}

puts ""
puts " UART Transmitter - Automated Test Execution"
puts " DUT        : $DUT_FILE"
puts " Test count : [llength $tests]"
puts " Log dir    : $LOG_DIR"
puts " Wave dir   : $WAVE_DIR"
puts ""
puts ""

set results {}
set n_pass 0
set n_fail 0
set ORIG_DIR [pwd]

foreach testname $tests {
    set tb_file  [file join $TB_DIR "${testname}.v"]
    set vvp_file [file join $TB_DIR "${testname}.vvp"]
    set log_file [file join $LOG_DIR "${testname}_log.txt"]
    set vcd_file [file join $TB_DIR "${testname}.vcd"]

    if {![file exists $tb_file]} {
        puts "  $testname ... SKIPPED (testbench file not found: $tb_file)"
        lappend results [list $testname "SKIPPED"]
        incr n_fail
        continue
    }

    file delete -force $vvp_file
    set compile_cmd [list iverilog -o $vvp_file -I $TB_DIR $DUT_FILE $tb_file]
    set compile_log ""
    if {[catch {set compile_log [exec {*}$compile_cmd 2>@1]} err]} {
        set compile_log $err
    }
    set compile_ok [file exists $vvp_file]

    if {!$compile_ok} {
        set fh [open $log_file w]
        puts $fh "COMPILE FAILED for $testname"
        puts $fh $compile_log
        close $fh
        puts "  $testname ... FAIL (compile error, see $log_file)"
        lappend results [list $testname "FAIL"]
        incr n_fail
        continue
    }

    cd $WAVE_DIR
    set run_log ""
    if {[catch {set run_log [exec $vvp_file 2>@1]} err]} {
        set run_log $err
    }
    cd $ORIG_DIR

    if {[file exists $vcd_file]} {
        file rename -force $vcd_file [file join $WAVE_DIR "${testname}.vcd"]
    }

    set fh [open $log_file w]
    puts $fh $run_log
    close $fh

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

puts ""
puts ""
puts " SUMMARY"
puts ""
foreach r $results {
    set nm     [lindex $r 0]
    set status [lindex $r 1]
    puts [format "  %-28s %s" "${nm}..." $status]
}
puts ""
puts "  TOTAL: [llength $tests]   PASS: $n_pass   FAIL/SKIPPED: $n_fail"
puts ""

if {$n_fail > 0} {
    exit 1
} else {
    exit 0
}
