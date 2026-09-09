# Copyright (c) 2025-2026 Antmicro <www.antmicro.com>
# SPDX-License-Identifier: Apache-2.0

TOPLEVEL = guineveer_cocotb_dut

SCRIPT_DIR := $(abspath ${CURDIR}/../../../)


VERILOG_SOURCES += $(abspath $(SCRIPT_DIR)/design/testbench/guineveer_cocotb_dut.sv)


HEX_FILE0 ?= $(abspath ${CURDIR}/../sw/build/core0/i3c-cocotb.hex)
HEX_FILE1 ?= $(abspath ${CURDIR}/../sw/build/core1/i3c-cocotb.hex)

COMPILE_ARGS += +define+HEX_FILE0='"'$(HEX_FILE0)'"'
COMPILE_ARGS += +define+HEX_FILE1='"'$(HEX_FILE1)'"'

VERILATOR_SKIP_WARNINGS = -Wno-REDEFMACRO -Wno-DEFOVERRIDE

include $(CURDIR)/../common.mk
