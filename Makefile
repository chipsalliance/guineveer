# Copyright (c) 2025-2026 Antmicro <www.antmicro.com>
# SPDX-License-Identifier: Apache-2.0

VEER_CONFIGURATION_FLAGS ?= \
    -fpga_optimize=1 \
    -unset=assert_on \
    -set=reset_vec=0x80000000 \
    -set=ret_stack_size=2 \
    -set=btb_enable=0 \
    -set=btb_size=8 \
    -set=bht_size=32 \
    -set=dccm_size=16 \
    -set=dccm_num_banks=2 \
    -set=iccm_enable=0 \
    -set=icache_enable=0 \
    -set=dccm_enable=0 \
    -set=dma_buf_depth=2 \
    -set=div_bit=1 \
    -set=pic_total_int=8 \

SCRIPT_DIR := $(patsubst %/,%,$(dir $(realpath $(lastword $(MAKEFILE_LIST)))))

include $(SCRIPT_DIR)/design/src/rtl.mk

LD_ABI := -mabi=ilp32 -march=rv32imac
CC_ABI := -mabi=ilp32 -march=rv32imc_zicsr_zifencei
GCC_PREFIX := riscv64-unknown-elf

TEST ?= uart
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
endif

-include $(TEST_DIR)/$(TEST).mki

TB_FILES = $(TB_DIR)/defines.sv $(VERILOG_SOURCES) $(TB_DIR)/guineveer_tb.sv 
TB_INCLS = $(VERILOG_INCLUDE_DIRS) $(TB_DIR) $(RV_ROOT)/testbench

# -Wno-REDEFMACRO is needed because RV_TOP is first defined in some header in caliptra-rtl,
# and then is redefined (to the correct value) in the VeeR config header.
VERILATOR_SKIP_WARNINGS = -Wno-REDEFMACRO

VERILATOR_DEBUG := --trace-fst --trace-structs

SOC_WRAPPER_DEPS := $(TW_DIR)/design-$(DESIGN).yaml

TW_REPO = repo
TW_REPO_DIR = $(TW_DIR)/$(TW_REPO)

TW_PARSE_FLAGS = \
	--inference \
	--inference-interface AXI4 \
	--inference-interface AHBguin

TW_AXI_PREREQ_SRCS = $(BUILD_DIR)/axi/src/axi_pkg.sv $(wildcard $(AXI_INCLUDE_PATH)/axi/*.svh)

# Renode script/platform description for simulations
RENODE_TEST_SRC = $(SCRIPT_DIR)/tests/renode/guineveer.repl \
									$(SCRIPT_DIR)/tests/renode/guieneveer_common.repl \
									$(SCRIPT_DIR)/tests/renode/guineveer.resc

all: testbench

clean: | $(BUILD_DIR)
	rm -rf $(BUILD_DIR) $(HW_DIR)/guineveer.sv
	CORE=core0 $(MAKE) -f $(SCRIPT_DIR)/tests/sw/Makefile clean
	CORE=core1 $(MAKE) -f $(SCRIPT_DIR)/tests/sw/Makefile clean


hw: $(VEER_SNAPSHOT) $(BUILD_DIR)/axi.f $(HW_DIR)/guineveer.sv

testbench: $(BUILD_DIR)/obj_dir/Vguineveer_tb | $(BUILD_DIR)

sim: $(BUILD_DIR)/sim.vcd

build_test: $(HEX_FILE_CORE0) $(HEX_FILE_CORE1)

renode_test: $(BUILD_DIR)/report.html

$(HEX_FILE_CORE0) $(ELF_FILE_CORE0):
	TEST=$(TEST) CORE=core0 $(MAKE) -f $(SCRIPT_DIR)/tests/sw/Makefile build

$(HEX_FILE_CORE1) $(ELF_FILE_CORE1):
	TEST=$(TEST) CORE=core1 $(MAKE) -f $(SCRIPT_DIR)/tests/sw/Makefile build

$(RENODE_TEST_SRC) &: $(TW_DIR)/design-dualcore.yaml
	mkdir -p $(SCRIPT_DIR)/build
	topwrap build -d $(TW_DIR)/design-dualcore.yaml --build-dir $(SCRIPT_DIR)/build
	cp $(SCRIPT_DIR)/build/*.repl $(SCRIPT_DIR)/build/*.resc $(SCRIPT_DIR)/tests/renode/

$(HW_DIR)/guineveer.sv: $(SOC_WRAPPER_DEPS) $(VERILOG_CORE_SOURCES) $(VERILOG_INCLUDE_DIRS)
# Input sync FFs are needed on FPGAs, as the option to disable them is only intended to be used on ASICs.
	sed -i.bak "/DISABLE_INPUT_FF/d" $(I3C_ROOT_DIR)/src/i3c_defines.svh

	topwrap build -d $(TW_DIR)/design-$(DESIGN).yaml --build-dir $(HW_DIR)

	sed -i.bak 's/axi_pkg/axi_axi_pkg/g' $(HW_DIR)/guineveer.sv


# This target is only included for reference.
# Running this target will lose all changes made to the IP core YAML files,
# such as adding clocks and resets or default values for ports.
regenerate_tw_repo: $(SOC_WRAPPER_DEPS) $(VERILOG_CORE_SOURCES) $(VERILOG_INCLUDE_DIRS)
	-rm -rf $(TW_REPO_DIR)
	-rm -f $(SCRIPT_DIR)/topwrap.yaml
	topwrap repo init $(TW_REPO) $(TW_REPO_DIR)
#	TODO: Ideally the interfaces in topwrap's built-in repo would be improved instead.
	cp -r $(TW_DIR)/interfaces $(TW_REPO_DIR)

	topwrap repo parse $(TW_REPO) $(VEER_SNAPSHOT)/common_defines.vh $(RV_ROOT)/design/lib/el2_mem_if.sv \
		$(RV_ROOT)/design/el2_veer_wrapper.sv $(TW_PARSE_FLAGS)
	topwrap repo parse $(TW_REPO) $(TW_AXI_PREREQ_SRCS) $(HW_DIR)/axi_cdc_wrapper.sv $(TW_PARSE_FLAGS)
	topwrap repo parse $(TW_REPO) $(TW_AXI_PREREQ_SRCS) $(HW_DIR)/sram_wrapper.sv $(TW_PARSE_FLAGS)
	topwrap repo parse $(TW_REPO) $(SCRIPT_DIR)/design/src/ipxact/AHBguin.xml $(SCRIPT_DIR)/design/src/ipxact/uart_wrapper.xml -f ipxact -e skip
	topwrap repo parse $(TW_REPO) $(RV_ROOT)/design/lib/axi4_to_ahb.sv $(TW_PARSE_FLAGS)
	topwrap repo parse $(TW_REPO) $(I3C_ROOT_DIR)/src/i3c_defines.svh $(I3C_ROOT_DIR)/src/i3c_wrapper.sv $(TW_PARSE_FLAGS) \
		--grouping-hint=AXI4=axi

$(VEER_SNAPSHOT): $(VEER_SNAPSHOT)/common_defines.vh
$(VEER_SNAPSHOT)/%: | $(BUILD_DIR)
	export RV_ROOT=$(RV_ROOT) && \
	cd $(BUILD_DIR) && \
	$(RV_ROOT)/configs/veer.config $(VEER_CONFIGURATION_FLAGS)

$(AXI_INCLUDE_PATH): $(BUILD_DIR)/axi.f
$(COMMON_CELLS_INCLUDE_PATH): $(BUILD_DIR)/axi.f
$(BUILD_DIR)/axi.f: $(HW_DIR)/gen_flist.sh | $(BUILD_DIR)
	mkdir -p $(BUILD_DIR)/axi
	cp $(AXI_SOURCE_DIR)/Bender.yml $(BUILD_DIR)/axi
	cp -r $(AXI_SOURCE_DIR)/src $(BUILD_DIR)/axi
	cp -r $(AXI_SOURCE_DIR)/include $(BUILD_DIR)/axi
	export OUTPUT_FILE_LOCATION=$@ && export BENDER_MANIFEST_DIR=$(BUILD_DIR)/axi && $<
# Replace axi_pkg with axi_axi_pkg in axi submodule due to package collision with caliptra-rtl
	find $(BUILD_DIR) -type f -name "*.sv" -exec sed -i.bak 's/axi_pkg/axi_axi_pkg/g' {} +
	find $(BUILD_DIR) -type f -name "*.svh" -exec sed -i.bak 's/axi_pkg/axi_axi_pkg/g' {} +

TESTBENCH_ARGS += +firmware0=$(HEX_FILE_CORE0)

ifeq ($(DESIGN),dualcore)
TESTBENCH_ARGS += +firmware1=$(HEX_FILE_CORE1)
VERILATOR_EXTRA_ARGS += -DDUALCORE
endif

$(BUILD_DIR)/sim.vcd: $(HEX_FILE_CORE0) $(HEX_FILE_CORE1) $(BUILD_DIR)/obj_dir/Vguineveer_tb | $(BUILD_DIR)
	cd $(BUILD_DIR) && ./obj_dir/Vguineveer_tb $(TESTBENCH_ARGS) ${TB_EXTRA_ARGS}

$(BUILD_DIR)/obj_dir/Vguineveer_tb: $(TB_FILES) $(TB_INCLS) $(TB_CPPS) | $(BUILD_DIR)
	verilator --cc -CFLAGS "-std=c++14 -O3" -coverage-max-width 20000 $(defines) \
	  $(addprefix -I,$(TB_INCLS)) -Mdir $(BUILD_DIR)/obj_dir \
	  $(VERILATOR_SKIP_WARNINGS) $(VERILATOR_EXTRA_ARGS) ${TB_FILES} --top-module guineveer_tb \
	  --main --exe --autoflush --timing $(VERILATOR_DEBUG) $(VERILATOR_COVERAGE) -fno-table
	$(MAKE) -e -C $(BUILD_DIR)/obj_dir/ -f Vguineveer_tb.mk $(VERILATOR_MAKE_FLAGS)

$(BUILD_DIR):
	mkdir -p $@

$(BUILD_DIR)/report.html: $(ELF_FILE_CORE0) $(ELF_FILE_CORE1) $(BUILD_DIR) $(RENODE_TEST_SRC)
ifneq ($(filter i3c_cosim axi-streaming-boot-dualcore,$(RENODE_TEST)),)
	make -C $(SCRIPT_DIR)/tests/renode/renode_i3c_cosim
endif
	cd $(BUILD_DIR) && renode-test $(SCRIPT_DIR)/tests/renode/guineveer_$(RENODE_TEST).robot

.PHONY: all clean hw testbench sim build_test renode_test regenerate_tw_repo

.PRECIOUS: $(BUILD_DIR)/sim.vcd
