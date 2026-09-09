# Copyright (c) 2025-2026 Antmicro <www.antmicro.com>
# SPDX-License-Identifier: Apache-2.0

$(info $(shell cocotb-config --makefiles))

TOPLEVEL_LANG    = verilog
SIM             ?= verilator
WAVES           ?= 1

comma := ,
empty :=
space := $(empty) $(empty)

JOBS ?= $(shell nproc)

# Paths
CURDIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

include $(CURDIR)/../../design/src/rtl.mk

TEST_FILES   = $(sort $(wildcard test_*.py))
MODULE      ?= $(subst $(space),$(comma),$(subst .py,,$(TEST_FILES)))

# Set pythonpath so that tests can access common modules
export PYTHONPATH := $(CURDIR)/common

# Coverage reporting
COVERAGE_TYPE ?= ""
ifeq ("$(COVERAGE_TYPE)", "all")
    VERILATOR_COVERAGE = --coverage
else ifeq ("$(COVERAGE_TYPE)", "branch")
    VERILATOR_COVERAGE = --coverage-line
else ifeq ("$(COVERAGE_TYPE)", "toggle")
    VERILATOR_COVERAGE = --coverage-toggle
else ifeq ("$(COVERAGE_TYPE)", "functional")
    VERILATOR_COVERAGE = --coverage-user
else
    VERILATOR_COVERAGE = ""
endif

ifeq ($(SIM), verilator)
    # look for local i3c_defines before fusesoc one.
    COMPILE_ARGS += -I$(HW_DIR)
    COMPILE_ARGS += --coverage-max-width 20000
    COMPILE_ARGS += --timing
    COMPILE_ARGS += $(VERILATOR_SKIP_WARNINGS) -CFLAGS -O3
    COMPILE_ARGS += --verilate-jobs $(JOBS)
    BUILD_ARGS += -j $(JOBS)

    EXTRA_ARGS   += --trace --trace-fst --trace-structs
    EXTRA_ARGS   += $(VERILATOR_COVERAGE) --no-public-flat-rw --public-depth 1
    EXTRA_ARGS   += -Wno-DECLFILENAME
endif

COCOTB_HDL_TIMEUNIT         = 1ns
COCOTB_HDL_TIMEPRECISION    = 10ps

# Build directory
ifneq ($(COVERAGE_TYPE),)
    SIM_BUILD := sim-build-$(COVERAGE_TYPE)
endif

SIM_BUILD := $(abspath $(or $(SIM_BUILD),sim_build))

CUSTOM_COMPILE_DEPS += $(FUSESOC_VC) $(WAIVERS) $(HW_DIR)/i3c_defines.svh

include $(shell cocotb-config --makefiles)/Makefile.sim

ifeq ($(SIM),verilator)
# Keep FuseSoC paths relative to its export, including paths in waivers.
CMD := cd $(dir $(FUSESOC_VC)) && $(CMD)
COMPILE_ARGS += -f $(notdir $(FUSESOC_VC)) --Mdir $(SIM_BUILD) $(TOPMODULE_ARG) $(WAIVERS)
endif
