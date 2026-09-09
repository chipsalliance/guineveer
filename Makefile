# Copyright (c) 2025-2026 Antmicro <www.antmicro.com>
# SPDX-License-Identifier: Apache-2.0

SCRIPT_DIR := $(patsubst %/,%,$(dir $(realpath $(lastword $(MAKEFILE_LIST)))))

include $(SCRIPT_DIR)/design/src/rtl.mk

TEST ?= uart
COCOTB_TEST ?= $(TEST)
COCOTB_TESTCASE ?=
COCOTB_DIR := $(if $(filter uart,$(COCOTB_TEST)),uart_core_ahb,$(if $(filter axi-streaming-boot-dualcore,$(COCOTB_TEST)),streaming-boot-axi-dualcore,$(COCOTB_TEST)))
RENODE_TEST ?= $(TEST)
HEX_FILE_CORE0 ?= $(SCRIPT_DIR)/tests/sw/build/core0/$(TEST).hex
ELF_FILE_CORE0 ?= $(SCRIPT_DIR)/tests/sw/build/core0/$(TEST).elf
HEX_FILE_CORE1 ?= $(SCRIPT_DIR)/tests/sw/build/core1/$(TEST).hex
ELF_FILE_CORE1 ?= $(SCRIPT_DIR)/tests/sw/build/core1/$(TEST).elf

DESIGN ?= singlecore
DUALCORE_ONLY_TESTS := axi-streaming-boot-dualcore i3c-dualcore
ifeq ($(DESIGN),singlecore)
ifneq ($(filter $(TEST),$(DUALCORE_ONLY_TESTS)),)
$(error $(TEST) isn\'t supported in singlecore architecture, use \'dualcore\')
endif
ifneq ($(filter $(COCOTB_DIR),streaming-boot-axi-dualcore),)
$(error $(COCOTB_TEST) isn\'t supported in singlecore architecture, use \'dualcore\')
endif
endif

TB_FILES = $(TB_DIR)/guineveer_tb.sv
TB_INCLS = $(HW_DIR) $(TB_DIR)

# -Wno-REDEFMACRO is needed because RV_TOP is first defined in some header in caliptra-rtl,
# and then is redefined (to the correct value) in the VeeR config header.
VERILATOR_SKIP_WARNINGS = -Wno-REDEFMACRO

VERILATOR_DEBUG := --trace-fst --trace-structs

SOC_WRAPPER_DEPS := $(TW_DIR)/design-$(DESIGN).yaml

FUSESOC ?= fusesoc
FUSESOC_DIR := $(BUILD_DIR)/fusesoc-verilator
FUSESOC_FPGA_DIR := $(BUILD_DIR)/fusesoc-fpga
FUSESOC_FPGA_VC := $(FUSESOC_FPGA_DIR)/guineveer_0.vc

# Read lazily, after FuseSoC has generated the file list. Source paths and
# +incdir+ entries are relative to the FuseSoC work directory.
FUSESOC_FPGA_FILELIST = $(file <$(FUSESOC_FPGA_VC))
FUSESOC_FPGA_SOURCES = $(addprefix $(FUSESOC_FPGA_DIR)/,$(filter %.sv %.v %.vh %.svh,$(FUSESOC_FPGA_FILELIST)))
FUSESOC_FPGA_INCLUDE_DIRS = $(addprefix $(FUSESOC_FPGA_DIR)/,$(patsubst +incdir+%,%,$(filter +incdir+%,$(FUSESOC_FPGA_FILELIST))))
FUSESOC_VC := $(FUSESOC_DIR)/guineveer_tb_0.1.vc
FUSESOC_AXI_DIR := $(SCRIPT_DIR)/.fusesoc-cores/pulp_axi
FUSESOC_COMMON_CELLS_DIR := $(SCRIPT_DIR)/.fusesoc-cores/pulp_common_cells

FUSESOC_CORES_ROOTS := \
	--cores-root $(DESIGN_DIR)/src \
	--cores-root $(TB_DIR) \
	--cores-root $(SCRIPT_DIR)/.fusesoc-cores/topwrap_cores \
	--cores-root $(SCRIPT_DIR)/topwrap-cores \
	--cores-root $(FUSESOC_AXI_DIR) \
	--cores-root $(FUSESOC_COMMON_CELLS_DIR)

# Renode script/platform description for simulations
RENODE_TEST_SRC = $(SCRIPT_DIR)/tests/renode/guineveer.repl \
									$(SCRIPT_DIR)/tests/renode/guineveer_common.repl \
									$(SCRIPT_DIR)/tests/renode/guineveer.resc

all: testbench

clean: | $(BUILD_DIR)
	$(MAKE) -C $(SCRIPT_DIR)/design/fpga clean
	rm -rf $(BUILD_DIR) $(DESIGN_DIR)/src/guineveer.sv .fusesoc-cores
	CORE=core0 $(MAKE) -f $(SCRIPT_DIR)/tests/sw/Makefile clean
	CORE=core1 $(MAKE) -f $(SCRIPT_DIR)/tests/sw/Makefile clean


cocotb: $(FUSESOC_VC) cocotb_sw
	$(MAKE) -C $(SCRIPT_DIR)/tests/cocotb verify FUSESOC_VC=$(FUSESOC_VC) COCOTB_TEST=$(COCOTB_DIR) COCOTB_TESTCASE=$(COCOTB_TESTCASE)

cocotb_sw:
	TEST=axi-streaming-boot-dualcore CORE=core0 $(MAKE) -f $(REPO_DIR)/tests/sw/Makefile build
	TEST=axi-streaming-boot-dualcore CORE=core1 $(MAKE) -f $(REPO_DIR)/tests/sw/Makefile build
	TEST=i3c-cocotb CORE=core0 $(MAKE) -f $(REPO_DIR)/tests/sw/Makefile build
	TEST=i3c-cocotb CORE=core1 $(MAKE) -f $(REPO_DIR)/tests/sw/Makefile build

fpga: fpga_no_sw build_test

# Used when there is custom firmware
fpga_no_sw: $(FUSESOC_FPGA_VC)
	$(MAKE) -C $(SCRIPT_DIR)/design/fpga generate_block_design \
	  HEX_FILE0="$(HEX_FILE_CORE0)" HEX_FILE1="$(HEX_FILE_CORE1)" \
	  VERILOG_SOURCES="$(FUSESOC_FPGA_SOURCES)" \
	  VERILOG_INCLUDE_DIRS="$(FUSESOC_FPGA_INCLUDE_DIRS)"

hw: $(FUSESOC_VC)

testbench: $(BUILD_DIR)/obj_dir/Vguineveer_tb | $(BUILD_DIR)

sim: $(BUILD_DIR)/sim.vcd

build_test: $(HEX_FILE_CORE0) $(HEX_FILE_CORE1)

renode_test: $(BUILD_DIR)/report.html

topwrap_update_library:
	cd $(SCRIPT_DIR) && topwrap library update

$(HEX_FILE_CORE0) $(ELF_FILE_CORE0):
	TEST=$(TEST) CORE=core0 $(MAKE) -f $(SCRIPT_DIR)/tests/sw/Makefile build

$(HEX_FILE_CORE1) $(ELF_FILE_CORE1):
	TEST=$(TEST) CORE=core1 $(MAKE) -f $(SCRIPT_DIR)/tests/sw/Makefile build

$(RENODE_TEST_SRC) &: $(TW_DIR)/design-dualcore.yaml $(SCRIPT_DIR)/topwrap.yaml topwrap_update_library
	mkdir -p $(SCRIPT_DIR)/build
	topwrap build -d $(TW_DIR)/design-dualcore.yaml --build-dir $(SCRIPT_DIR)/build
	cp $(SCRIPT_DIR)/build/*.repl $(SCRIPT_DIR)/build/*.resc $(SCRIPT_DIR)/tests/renode/

$(DESIGN_DIR)/src/guineveer.sv $(DESIGN_DIR)/src/guineveer.core &: $(SOC_WRAPPER_DEPS) $(SCRIPT_DIR)/topwrap.yaml topwrap_update_library
	topwrap generate $(TW_DIR)/design-$(DESIGN).yaml -t $(DESIGN_DIR) --verilog --fusesoc
	sed -i.bak 's/axi_pkg/axi_axi_pkg/g' $(DESIGN_DIR)/src/guineveer.sv

$(FUSESOC_VC): topwrap_update_library $(DESIGN_DIR)/src/guineveer.sv $(DESIGN_DIR)/src/guineveer.core $(TB_DIR)/guineveer_tb.core $(TB_DIR)/defines.sv $(TB_FILES) $(SCRIPT_DIR)/Makefile
	cd $(SCRIPT_DIR) && $(FUSESOC) \
	  $(FUSESOC_CORES_ROOTS) \
	  run --target default --tool verilator --setup \
	  --work-root $(FUSESOC_DIR) ::guineveer_tb:0.1
# Workaround: PULP and Caliptra define different axi_pkg packages. Rename
# only the exported PULP sources and headers, leaving Caliptra unchanged.
	for axi_root in "$(FUSESOC_DIR)"/src/pulp-platform.org__axi_*; do \
	  find "$$axi_root" -type f \( -name '*.sv' -o -name '*.svh' \) \
	    -exec sed -i 's/\<axi_pkg\>/axi_axi_pkg/g' {} + || exit 1; \
	done

$(FUSESOC_FPGA_VC): topwrap_update_library $(DESIGN_DIR)/src/guineveer.sv $(DESIGN_DIR)/src/guineveer.core $(SCRIPT_DIR)/Makefile
	cd $(SCRIPT_DIR) && $(FUSESOC) \
	  $(FUSESOC_CORES_ROOTS) \
	  run --target default --tool verilator --setup \
	  --work-root $(FUSESOC_FPGA_DIR) ::guineveer
# Workaround: PULP and Caliptra define different axi_pkg packages. Rename
# only the exported PULP sources and headers, leaving Caliptra unchanged.
	for axi_root in "$(FUSESOC_FPGA_DIR)"/src/pulp-platform.org__axi_*; do \
	  find "$$axi_root" -type f \( -name '*.sv' -o -name '*.svh' \) \
	    -exec sed -i 's/\<axi_pkg\>/axi_axi_pkg/g' {} + || exit 1; \
	done

ipxact_gen: $(SOC_WRAPPER_DEPS) $(SCRIPT_DIR)/topwrap.yaml topwrap_update_library | $(BUILD_DIR)
	topwrap generate $(TW_DIR)/design-$(DESIGN).yaml -t $(BUILD_DIR)/ipxact --ipxact


TESTBENCH_ARGS += +firmware0=$(HEX_FILE_CORE0)

ifeq ($(DESIGN),dualcore)
TESTBENCH_ARGS += +firmware1=$(HEX_FILE_CORE1)
VERILATOR_EXTRA_ARGS += -DDUALCORE
endif

$(BUILD_DIR)/sim.vcd: $(HEX_FILE_CORE0) $(HEX_FILE_CORE1) $(BUILD_DIR)/obj_dir/Vguineveer_tb | $(BUILD_DIR)
	cd $(BUILD_DIR) && ./obj_dir/Vguineveer_tb $(TESTBENCH_ARGS) ${TB_EXTRA_ARGS}

$(BUILD_DIR)/obj_dir/Vguineveer_tb: $(FUSESOC_VC) $(TB_DIR)/defines.sv $(TB_FILES) $(TB_INCLS) $(HW_DIR)/waivers.vlt | $(BUILD_DIR)
	cd $(FUSESOC_DIR) && verilator $(WAIVERS) $(TB_DIR)/defines.sv \
	  --cc -CFLAGS "-std=c++14 -O3" -coverage-max-width 20000 \
	  $(addprefix -I,$(TB_INCLS)) \
	  $(VERILATOR_SKIP_WARNINGS) $(VERILATOR_EXTRA_ARGS) \
	  -f $(FUSESOC_VC) --Mdir $(BUILD_DIR)/obj_dir --top-module guineveer_tb \
	  --main --exe --autoflush --timing $(VERILATOR_DEBUG) $(VERILATOR_COVERAGE) -fno-table
	$(MAKE) -e -C $(BUILD_DIR)/obj_dir/ -f Vguineveer_tb.mk $(VERILATOR_MAKE_FLAGS)

$(BUILD_DIR):
	mkdir -p $@

ifneq ($(filter i3c_cosim axi-streaming-boot-dualcore,$(RENODE_TEST)),)
$(BUILD_DIR)/report.html: $(FUSESOC_VC)
endif

$(BUILD_DIR)/report.html: $(ELF_FILE_CORE0) $(ELF_FILE_CORE1) $(BUILD_DIR) $(RENODE_TEST_SRC)
ifneq ($(filter i3c_cosim axi-streaming-boot-dualcore,$(RENODE_TEST)),)
	$(MAKE) -C $(SCRIPT_DIR)/tests/renode/renode_i3c_cosim FUSESOC_VC=$(FUSESOC_VC)
endif
	cd $(BUILD_DIR) && renode-test $(SCRIPT_DIR)/tests/renode/guineveer_$(RENODE_TEST).robot

.PHONY: all clean fpga hw cocotb cocotb_sw testbench sim build_test renode_test ipxact_gen topwrap_update_library fpga_no_sw

.PRECIOUS: $(BUILD_DIR)/sim.vcd
