#!/bin/bash
#
# Antmicro's vivado tcl generator
# author: pgielda@antmicro.com
#
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2025-2026 Antmicro <www.antmicro.com>


# 1. Set important project information (adjust)
PROJECT_NAME="guineveer"
DEFAULT_LANG="Verilog"
TOP_LEVEL="top"
SCRIPT_DIR=$(realpath $(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)) # The full directory name of the script no matter where it is being called from
BOARD="${BOARD:="Arty-A7-100T"}"
CONSTR="$BOARD.xdc"

# Select customized options and sources for a specific board
case "$BOARD" in
  "Arty-A7-100T")
    PART_NAME="xc7a100t" ;;
  "NexysVideo-A7-200T")
    PART_NAME="xc7a200t" ;;
  *)
    echo "Unknown board: $BOARD" 1>&2
    exit 1 ;;
esac

# 2. Save last project regeneration time
echo
echo "#"
echo -n "# script generated @ "
date
echo "#"
echo

# 3. Create a new project
mkdir -p $SCRIPT_DIR/build
echo "create_project ${PROJECT_NAME} ${SCRIPT_DIR}/build/${PROJECT_NAME}_${BOARD} -part ${PART_NAME} -force"
echo "set_property target_language ${DEFAULT_LANG} [current_project]"

# 4. Include directories
echo "set_property include_dirs \"${INCLUDE_DIRS}\" [get_filesets sources_1]"

# 5. Import VHDL and Verilog files
for f in $HDL_SOURCES
do
  if [ -f $f ];
  then
    echo "import_files -fileset sources_1 ${f}"
  fi
done

# Top-level wrapper
echo "import_files -fileset sources_1 $SCRIPT_DIR/top.sv"

# FuseSoC lists include directories rather than individual include files in .vc.
# Import headers so Vivado can apply the global-include properties below.
for dir in $INCLUDE_DIRS; do
  for header in "$dir"/*.vh "$dir"/*.svh; do
    if [ -f "$header" ]; then
      echo "import_files -fileset sources_1 ${header}"
    fi
  done
done

# 6. Import constraints
echo "import_files -fileset constrs_1 $SCRIPT_DIR/constrs/$CONSTR"

# 7. Custom rules for the project, i.e. header imports (adjust)
echo "set_property is_global_include true [get_files -filter {NAME =~ *common_defines.vh}]"
echo "set_property is_global_include true  [get_files -filter {NAME =~ *el2_pdef.vh}]"
echo "set_property file_type SystemVerilog  [get_files -filter {NAME =~ *el2_pdef.vh}]"
echo "set_property is_global_include true [get_files -filter {NAME =~ *i3c_sva.svh}]"
echo "set_property file_type SystemVerilog [get_files -filter {NAME =~ *i3c_sva.svh}]"

echo "# Set specific Verilog files explicitly to SystemVerilog type"
echo "set_property file_type SystemVerilog [get_files dmi_jtag_to_core_sync.v]"
echo "set_property file_type SystemVerilog [get_files rvjtag_tap.v]"
echo "set_property file_type SystemVerilog [get_files dmi_mux.v]"

if [ -n "$HEX_FILE0" ] && [ -n "$HEX_FILE1" ];
then
  echo "# Initialize memory with a provided file"
  echo "set_property verilog_define {HEX_FILE0=\"$HEX_FILE0\" HEX_FILE1=\"$HEX_FILE1\"} [current_fileset]"
  echo "if { ![file exists \"$HEX_FILE0\"] } { error \"Could not find the provided memory file: '$HEX_FILE0'\" }"
  echo "if { ![file exists \"$HEX_FILE1\"] } { error \"Could not find the provided memory file: '$HEX_FILE1'\" }"
fi

echo "set_property top ${TOP_LEVEL} [current_fileset]"

echo
echo "launch_runs synth_1 -jobs $(nproc)"
echo "wait_on_run synth_1"

echo "launch_runs impl_1 -to_step write_bitstream -jobs $(nproc)"
echo "wait_on_run impl_1"
