# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2025-2026 Antmicro <www.antmicro.com>

FPGA_SCRIPT_DIR := $(patsubst %/,%,$(dir $(realpath $(lastword $(MAKEFILE_LIST)))))
.DEFAULT_GOAL := generate_block_design
TCL_FILE := $(FPGA_SCRIPT_DIR)/guineveer.tcl
BOARD ?= Arty-A7-100T

TEST ?= uart

HEX_FILE0 ?= $(FPGA_SCRIPT_DIR)/../../tests/sw/build/core0/$(TEST).hex
HEX_FILE1 ?= $(FPGA_SCRIPT_DIR)/../../tests/sw/build/core1/$(TEST).hex

generate_block_design: $(TCL_FILE)

$(TCL_FILE): $(FPGA_SCRIPT_DIR)/generate_project.sh FORCE
	HDL_SOURCES="$(VERILOG_SOURCES)" INCLUDE_DIRS="$(VERILOG_INCLUDE_DIRS)" HEX_FILE0=$(HEX_FILE0) HEX_FILE1=$(HEX_FILE1) BOARD=$(BOARD) $< > $(TCL_FILE)

clean:
	rm -f $(TCL_FILE)
	rm -rf $(FPGA_SCRIPT_DIR)/build

FORCE:

.PHONY: generate_block_design clean FORCE
