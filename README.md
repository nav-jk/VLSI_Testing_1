# UART Transmitter - Functional Verification

Self-checking testbenches and automated test execution for a UART Transmitter,
covering 15 key functionalities with Directed, Random, and Corner-Case tests.

## Folder structure

```
rtl/        uart_tx.v              - the DUT (UART Transmitter)
tb/         test01_*.v ... test15_*.v   - one testbench per functionality
            uart_common.vh         - shared testbench tasks (included by every test)
scripts/    run_tests.tcl          - automation script
            test_list.txt          - list of tests to run, in order
logs/       <testname>_log.txt     - console output of each test (generated)
waveforms/  <testname>.vcd         - waveform dump of each test (generated)
```

## Requirements

- Icarus Verilog (`iverilog`, `vvp`)
- Tcl (`tclsh`)

Install on Ubuntu/Debian/WSL:
```
sudo apt-get install iverilog tcl
```

Install on Mac (Homebrew):
```
brew install icarus-verilog tcl-tk
```

## Running all tests

```
cd scripts
tclsh run_tests.tcl
```

This compiles each testbench against the DUT, runs it, saves its console
output to `logs/<testname>_log.txt`, saves its waveform to
`waveforms/<testname>.vcd`, scans the log for the word FAIL, and prints a
PASS/FAIL summary for all 15 tests. Exits with code 0 if everything passed,
1 otherwise.

## Running a single test manually

```
cd tb
iverilog -o test01.vvp ../rtl/uart_tx.v test01_idle_state.v
vvp test01.vvp
```

## Viewing a waveform

```
gtkwave waveforms/test01_idle_state.vcd
```

## Functionalities covered

1. Idle state
2. Start bit generation
3. LSB-first bit ordering
4. Data pattern integrity
5. Stop bit generation
6. Baud rate accuracy
7. Boundary baud divisor values
8. Busy/TX-active flag
9. Done/TX-complete pulse
10. Ready-to-load flag
11. Even parity correctness
12. Odd parity correctness
13. Load new data while busy (should be ignored)
14. Back-to-back transmission
15. Reset during active transmission