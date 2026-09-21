#!/usr/bin/env bash
set -euo pipefail
mkdir -p sim
iverilog -g2005 -Wall -o sim/flowguard.out rtl/*.v tb/*.v
vvp sim/flowguard.out
