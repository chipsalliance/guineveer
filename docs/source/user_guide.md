# User guide

## Building SoC sources

Use the `make hw` command to generate the top module in `hw/guineveer.sv`, using Topwrap and the neccesary files, in the `build/` folder.
This command also creates an AXI interconnect that is generated and merged into `hw/guineveer.sv`

## Building software examples

Run `TEST=software_example_name make build_test` to compile one of the provided software samples.
As of right now, the available samples are:
* `uart` - initializes and transfers a "Hello UART" string over UART,
* `i3c` - checks the I3C register values after reset and initializes the peripheral in device mode,
* `i3c-cocotb` - checks communication over I3C; intended to be used with the I3C Cocotb tests,
* `axi-streaming-boot-dualcore` - uses `i3c-core`'s streaming boot capabilites, requires `dualcore` design.

## Different designs
By setting the `DESIGN` environmental variable, you can choose between different Topwrap configurations. 

Currently available options:
* `dualcore`: Features two VeeR cores and two memory modules,
* `singlecore`: Features a single VeeR core.

By default, `singlecore` is used.

## Topwrap libraries

Guineveer uses IP core and interface definitions from `topwrap-cores`.
The libraries are configured in `topwrap.yaml` and updated by the Makefile using `topwrap library update`.
FuseSoC resolves their RTL dependencies and exports the source lists used by the builds.

## Building the testbench simulation

Run the `make testbench` command to generate the simulation testbench executable using `Verilator`.
The program is placed in the `build/obj_dir/Vguineveer_tb` file.
It can be launched with `+firmware0=/path/to/the/core0.hex +firmware1=/path/to/the/core1.hex` (with the selected firmware).

~~~{note}
Please note that Guineveer's RAM is placed at the offset `0x80000000` and the firmware is loaded using the \\$readmemh task.
If the hex file was created using `objdump -O verilog`, it will have addresses starting at offset `0x80000000`, but \\$readmemh expects the starting address `0x0`.
Remember to change the addresses to comply with the address range required by \\$readmemh.
~~~

## Building designs for FPGA

* From the repository root, run `make fpga BOARD=<board> TEST=<test>` to build the firmware, export the RTL sources, and generate `design/fpga/guineveer.tcl`.
* To use existing firmware, run `make fpga_no_sw BOARD=<board> HEX_FILE_CORE0=/path/to/core0.hex HEX_FILE_CORE1=/path/to/core1.hex` from the repository root.
    The supported boards are `NexysVideo-A7-200T` and `Arty-A7-100T`.
* To synthesize Guineveer using Vivado, run `vivado -mode batch -script design/fpga/guineveer.tcl` from the repository root.

## Running an example SW using the testbench

Run `TEST=software_example_name make sim` to launch the testbench executable with the provided software.
The log of all register values and their changes throughout the simulation will be written in the `build/exec.log` file.

## Running an example SW using Renode Robot Framework

Run `TEST=software_example_name make renode_test` to launch the Renode simulation with the provided software.
It will run the software and compare its output with the expected values.

## Running an example SW using Renode Robot Framework with cosimulation

Run `make` in the `sw/renode_i3c_cosim` directory to build the co-simulation binary of the I3C device from the HDL sources.
After building the co-simulation binary and the `i3c` test software, `renode-test` can be used to run the test, available in the `sw/guineveer_i3c_cosim.robot` file.
Refer to the following chapters in Renode's documentation for a detailed overview of the required dependencies and available options:
* [Testing with Renode](https://renode.readthedocs.io/en/latest/introduction/testing.html)
* [Co-simulating with an HDL simulator](https://renode.readthedocs.io/en/latest/advanced/co-simulating-with-an-hdl-simulator.html)

## Generating IPXACT 2022 files

Run `make ipxact_gen` to generate IPXACT files in `build/ipxact`. Supported IPXACT version is 2022.
Due to existing Topwrap limitations parameters aren't elaborated. It is recommended to use `sed` command to replace parameters with selected values.
