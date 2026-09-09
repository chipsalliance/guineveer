# Copyright (c) 2025-2026 Antmicro <www.antmicro.com>
# SPDX-License-Identifier: Apache-2.0

# Makefile fragment that provides variables with all the Verilog sources.

REPO_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/../..)

DESIGN_DIR := $(REPO_DIR)/design
HW_DIR := $(DESIGN_DIR)/src
TB_DIR := $(DESIGN_DIR)/testbench
TW_DIR := $(REPO_DIR)/topwrap
BUILD_DIR := $(REPO_DIR)/build

WAIVERS := $(HW_DIR)/waivers.vlt
