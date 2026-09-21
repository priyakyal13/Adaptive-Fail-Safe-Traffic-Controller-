# FlowGuard-RTL (Verilog)

Adaptive, fair and fail-safe traffic controller implemented in plain
Verilog (IEEE 1364-2005) — no SystemVerilog constructs used.

## What makes it more than a basic traffic-light FSM

1. **Adaptive green time** — 3-bit traffic demand (`0..7`) changes the
   green duration between `MIN_GREEN` and `MAX_GREEN`.
2. **Bounded waiting** — active-demand directions accumulate a wait
   counter; reaching `MAX_WAIT` gives that direction priority at the next
   safe scheduling point.
3. **Fail-safe outputs** — an independent safety monitor forces both
   roads to red if the FSM enters an illegal state or produces an
   invalid light combination.

## Architecture

```text
              traffic_ns / traffic_ew
                       |
                       v
              +------------------+
              | Priority Scheduler|
              | demand + aging    |
              | bounded waiting   |
              +--------+---------+
                       |
                       v
                +-------------+
                | Traffic FSM  |
                | 5 states     |
                | phase timing |
                +------+------+
                       |
                       v
              +------------------+
              | Safety Monitor   |
              | fail-safe logic  |
              +--------+---------+
                       |
                       v
                Traffic outputs
```

## Files

```text
FlowGuard-RTL/
├── rtl/
│   ├── flowguard_top.v       # Top-level integration + wait counters
│   ├── priority_scheduler.v  # Demand, aging and bounded-wait arbitration
│   ├── traffic_fsm.v         # Five-state Moore FSM + timing
│   └── safety_monitor.v      # Independent fail-safe checker
├── tb/
│   └── sanity_tb.v           # Self-checking regression testbench
├── sim/                      # Generated simulation files
├── run.sh                    # Linux/macOS simulation script
├── run.bat                   # Windows simulation script
├── README.md
├── DESIGN_NOTES.md
├── VERIFICATION_REPORT.md
└── .gitignore
```

## Inputs

`traffic_ns` and `traffic_ew` are 3-bit demand levels:

| Value | Meaning |
|---:|---|
| 0 | No active demand |
| 1-2 | Low |
| 3-4 | Medium |
| 5-6 | High |
| 7 | Very high |

## Green-time policy

```text
green_time = MIN_GREEN + 2 * traffic_level
```

Capped at `MAX_GREEN`.

## Fairness policy

For an active-demand direction:

```text
wait counter increases while not green
wait counter resets while green
```

Once a direction reaches `MAX_WAIT`, the scheduler gives it priority at
the next scheduling point, unless the other direction is also at the
fairness limit. Ties are resolved by alternating from the last served
direction. An empty direction does not accumulate wait debt.

## Safety policy

The safety monitor checks that the FSM state matches exactly one legal
light combination. Any invalid state or invalid combination drives:

```text
NS = RED
EW = RED
```

Reset also lands in the safe `ALL_RED` state (not a green phase) — see
`VERIFICATION_REPORT.md` for the bug this fixes.

## Simulation

Requires [Icarus Verilog](http://iverilog.icarus.com/).

### Linux / macOS

```bash
chmod +x run.sh
./run.sh
```

### Windows

```bat
run.bat
```

Both scripts compile with `-g2005` (plain Verilog mode — rejects any
SystemVerilog-only syntax, so this is a hard guarantee the project is
pure Verilog, not just SystemVerilog-that-happens-to-run).

Expected ending:

```text
ALL SANITY CHECKS PASSED
```

A VCD waveform is written to `sim/sanity.vcd`.

## GTKWave

```bash
gtkwave sim/sanity.vcd
```

Useful signals:

```text
traffic_ns
traffic_ew
state
selected_dir
ns_green_time
ew_green_time
wait_ns
wait_ew
ns_red/ns_yellow/ns_green
ew_red/ew_yellow/ew_green
fault
```
