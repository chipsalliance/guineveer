# Testing

The Guineveer SoC supports the following targets:

* HDL simulation
* Renode simulation and co-simulation
* FPGA
* ASIC (in progress)
## Software tests

Currently, these software test samples are available:
* `uart` - example that initializes and transmits `Hello UART` over UART
* `i3c` - example that verifies the correctness of some basic operations on the `i3c` device, including:
    * verifying if registers contain expected values after reset
    * verifying if read-only registers are not writeable and if read-write registers are writable
    * verifying if status bits change values after an interrupt condition is forced
* `i3c-cocotb` - test application dedicated for use with the Cocotb I3C tests, which cover:
    * waiting for dynamic address assignment and observing the register changes,
    * performing I3C private writes and reads to the device,
    * performing various directed CCC transactions,
    * performing a streaming boot via the recovery I3C target,
    * performing a streaming boot using the AXI bypass functionality.
* `axi-streaming-boot-dualcore` - example that tests the AXI streaming boot feature of `i3c-core` using two cores
    * core 0 waits for payload from `i3c-core` via registers
    * core 1 sends payload to `i3c-core` via registers
    * payload can be modified and rebuild; the source files are located in `tests/sw/axi-streaming-boot-dualcore/core1/payload`
    * payload size is limited in the core 0 software; to increase the limit, change `MAX_STREAMING_BOOT_SIZE`
    * requires `dualcore` design

Building software examples is described in the [User guide](user_guide.md#building-software-examples).

### Running software tests

Software tests can be run in multiple ways:
* in Verilator,
* in Renode, with a behavioral model of the I3C device,
* in Renode, with a co-simulated model of the I3C device, generated from the original HDL sources.

Running the test software using each of the available methods is described in the [User guide](user_guide.md#running-an-example-sw-using-the-testbench)

## Cocotb tests

Run these commands from the repository root. The Makefile prepares the FuseSoC
source list and test firmware before launching Cocotb.

```sh
make cocotb COCOTB_TEST=uart
make cocotb COCOTB_TEST=i3c
make cocotb DESIGN=dualcore COCOTB_TEST=axi-streaming-boot-dualcore
```

The default suite is UART. Set `COCOTB_TESTCASE` to a test function name
to run one case from the selected suite. JUnit results are written to
`tests/cocotb/<suite-directory>/results/all.xml` for a full suite or
`tests/cocotb/<suite-directory>/results/<testcase>.xml` for one case.
The suite directories are `uart_core_ahb`, `i3c` and
`streaming-boot-axi-dualcore`, respectively.

## FPGA tests
## Supported FPGA boards
* [Arty A7-100T](https://store.digilentinc.com/arty-a7-artix-7-fpga-development-board/) is an FPGA development board based on the Xilinx Artix-7 FPGA.
