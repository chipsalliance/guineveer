SCRIPT_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ROOT_DIR := $(abspath $(SCRIPT_DIR)/../../../)
BUILD_DIR := $(ROOT_DIR)/build/renode_i3c_cosim

FUSESOC_VC ?= $(ROOT_DIR)/build/fusesoc-verilator/guineveer_tb_0.1.vc

# Use the same I3C wrapper variant as the shared SoC export.
I3C_WRAPPER = $(if $(findstring antmicro.com_topwrap-cores_i3c_axi_controller_target_,$(file <$(FUSESOC_VC))),i3c_axi_controller_target,i3c_axi_target)
defines = +define+DIGITAL_IO_I3C=1 +define+RENODE_I3C_WRAPPER=$(I3C_WRAPPER)

RENODE_LIB_DIR := $(ROOT_DIR)/third_party/renode/src/Plugins/CoSimulationPlugin/IntegrationLibrary/
RENODE_SRCLIST := $(RENODE_LIB_DIR)/hdl/imports/renode_axi_pkg.sv \
	$(RENODE_LIB_DIR)/hdl/renode_pkg.sv \
	$(RENODE_LIB_DIR)/hdl/modules/renode_inputs.sv \
	$(RENODE_LIB_DIR)/hdl/modules/renode.sv \
	$(RENODE_LIB_DIR)/hdl/modules/axi/renode_axi_if.sv \
	$(RENODE_LIB_DIR)/hdl/modules/axi/renode_axi_manager.sv \
	$(RENODE_LIB_DIR)/src/renode_dpi.cpp \
	$(RENODE_LIB_DIR)/src/communication/socket_channel.cpp \
	$(RENODE_LIB_DIR)/libs/socket-cpp/Socket/TCPClient.cpp \
	$(RENODE_LIB_DIR)/libs/socket-cpp/Socket/Socket.cpp
RENODE_INCLIST := $(RENODE_LIB_DIR) \
	$(RENODE_LIB_DIR)/hdl \
	$(RENODE_LIB_DIR)/hdl/includes \
	$(RENODE_LIB_DIR)/src

ALL_SRCS = $(ROOT_DIR)/design/src/waivers.vlt $(RENODE_SRCLIST) $(SCRIPT_DIR)/renode_i3c_cosim.sv
ALL_INCLS = $(ROOT_DIR)/design/src $(RENODE_INCLIST) $(VERILOG_INCLUDE_DIRS)

VERILATOR_SKIP_WARNINGS := $(VERILATOR_NOIMPLICIT) -Wno-TIMESCALEMOD -Wno-SELRANGE \
	-Wno-CASEINCOMPLETE -Wno-INITIALDLY -Wno-WIDTH -Wno-UNOPTFLAT -Wno-REDEFMACRO \
	-Wno-LATCH -Wno-MULTIDRIVEN -Wno-UNSIGNED -Wno-CMPCONST

$(BUILD_DIR)/Vsim: $(FUSESOC_VC) $(ALL_SRCS) $(ALL_INCLS) \
    $(ROOT_DIR)/design/src/i3c_defines.svh $(ROOT_DIR)/design/testbench/defines.sv \
    $(SCRIPT_DIR)/Makefile | $(BUILD_DIR)
# FuseSoC file paths and waivers are relative to the export directory.
	+cd $(dir $(FUSESOC_VC)) && verilator --cc -CFLAGS "-std=c++14" -coverage-max-width 20000 $(defines) \
	  $(addprefix -I,$(ALL_INCLS)) \
	  $(VERILATOR_SKIP_WARNINGS) $(VERILATOR_EXTRA_ARGS) \
	  $(ROOT_DIR)/design/testbench/defines.sv -f $(FUSESOC_VC) \
	  $(ALL_SRCS) --Mdir $(BUILD_DIR) --top-module sim\
	  --main --exe --build --autoflush --timing $(VERILATOR_DEBUG) $(VERILATOR_COVERAGE) -fno-table

$(BUILD_DIR):
	mkdir -p $@
