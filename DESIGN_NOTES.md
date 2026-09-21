# FlowGuard-RTL Design Notes (Verilog version)

## Why plain Verilog and not SystemVerilog

This version deliberately avoids SystemVerilog-only constructs:

| SystemVerilog | Plain Verilog equivalent used here |
|---|---|
| `logic` | `wire` (structural signals) or `reg` (anything assigned inside an `always` block) |
| `always_comb` | `always @(*)` |
| `always_ff @(posedge clk or posedge rst)` | `always @(posedge clk or posedge rst)` |
| `parameter int unsigned X = ...` | `parameter X = ...` (untyped) |
| `integer unsigned x;` | `integer x;` (Verilog's `integer` is signed 32-bit; values here are always non-negative so this is safe) |
| `localparam logic [2:0] X = ...` | `localparam [2:0] X = ...` |
| `.*` implicit port connection in the testbench | every port connected explicitly by name |
| `task automatic f(input int n);` | plain `task` with `input integer n;` |

The compile is done with `iverilog -g2005`, which is Icarus Verilog's
strict plain-Verilog mode — it will reject any SystemVerilog-only syntax
outright, so a clean compile under this flag is a real guarantee, not
just "it happens to work."

## State machine

The controller has five legal states:

```text
NS_GREEN -> NS_YELLOW -> ALL_RED -> EW_GREEN -> EW_YELLOW -> ALL_RED -> ...
```

The direction after `ALL_RED` is selected by the priority scheduler.

If the FSM is ever forced into an illegal state, the combinational
next-state logic drives it toward `ALL_RED`, and the safety monitor
immediately forces the external outputs to all-red.

## Reset behavior (and the bug that was here)

Reset lands directly in `ALL_RED` — the fail-safe state — not in a green
phase. An earlier version of this design reset straight into `NS_GREEN`,
which meant `ns_green` was asserted for one clock edge while `rst` was
still held high. That both violated the project's own "always recover to
a safe state" principle and was the exact cause of a testbench failure
(`green = 7 cycles measured, 6 expected` — the extra reset-time cycle was
being counted). See `VERIFICATION_REPORT.md`.

## Why both scheduler and FSM are separate

The scheduler answers: *which direction should receive the next green
phase?* The FSM answers: *what phase is the controller currently in, and
how long should that phase last?* Keeping these concerns separate makes
the RTL easier to verify, modify and explain.

## Fairness mechanism

Wait counters saturate at `MAX_WAIT`. A direction with `traffic == 0` has
its wait counter cleared, so an empty road never eventually "wins" just
because time passed.

## Safety mechanism

The safety monitor checks the decoded state against all six output
signals, not just the two green signals — a partially corrupted output
pattern is also detected, not just a fully wrong one.

## Future extensions deliberately left out

- SystemVerilog Assertions (SVA) / formal proof — intentionally not used
  here since the project targets plain Verilog.
- cocotb or UVM verification.
- FPGA synthesis and timing comparison.
- AXI/APB configuration registers.
- sensor-interface RTL.
