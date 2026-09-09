# Copyright (c) 2025-2026 Antmicro <www.antmicro.com>
# SPDX-License-Identifier: Apache-2.0

TOPLEVEL = uart_top_wrapper

VERILOG_SOURCES := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))/uart_top_wrapper.sv

COMPILE_ARGS := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))/../../../design/testbench/defines.sv
VERILATOR_SKIP_WARNINGS = -Wno-REDEFMACRO

include $(CURDIR)/../common.mk
