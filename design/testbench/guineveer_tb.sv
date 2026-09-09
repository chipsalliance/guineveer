// SPDX-License-Identifier: Apache-2.0
// Copyright 2019 Western Digital Corporation or its affiliates.
// Copyright (c) 2025-2026 Antmicro <www.antmicro.com>
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

`timescale 1ns / 1ps

`define COMMON_CELLS_ASSERTS_OFF

module guineveer_tb
  import el2_pkg::*;
#(
    parameter int MAX_CYCLES = 100_000_000,
    `include "el2_param.vh"
) ();
  bit                         core_clk;
  bit                         i3c_clk;
  bit                         rst_l;

  bit    [              31:0] mem_signature_begin;
  bit    [              31:0] mem_signature_end;
  bit    [              31:0] mem_mailbox;
  bit                         i_cpu_halt_req;
  bit                         o_cpu_halt_ack;
  bit                         o_cpu_halt_status;
  bit                         i_cpu_run_req;
  bit                         o_cpu_run_ack;
  bit                         mpc_debug_halt_req;
  bit                         mpc_debug_halt_ack;
  bit                         mpc_debug_run_req;
  bit                         mpc_debug_run_ack;
  bit                         o_debug_mode_status;
  bit                         lsu_bus_clk_en;
  logic                       uart_rx;
  logic                       uart_tx;

  logic                       i3c_scl_i;
  logic                       i3c_sda_i;
  logic                       i3c_scl_o;
  logic                       i3c_sda_o;
  logic                       i3c_scl_oe;
  logic                       i3c_sda_oe;
  logic                       i3c_sel_od_pp_o;

  logic                       porst_l;
  logic  [pt.PIC_TOTAL_INT:1] extintsrc_req;
  logic                       nmi_int;
  logic                       timer_int;
  logic                       soft_int;

  logic  [              31:0] reset_vector;
  logic  [              31:0] nmi_vector;
  logic  [              31:1] jtag_id;

  logic  [              31:0] trace_rv_i_insn_ip;
  logic  [              31:0] trace_rv_i_address_ip;
  logic                       trace_rv_i_valid_ip;
  logic                       trace_rv_i_exception_ip;
  logic  [               4:0] trace_rv_i_ecause_ip;
  logic                       trace_rv_i_interrupt_ip;
  logic  [              31:0] trace_rv_i_tval_ip;

  logic                       jtag_tdo;
  logic                       jtag_tck;
  logic                       jtag_tms;
  logic                       jtag_tdi;
  logic                       jtag_trst_n;

  logic                       mailbox_write;
  logic  [              63:0] mailbox_data;

  int                         cycleCnt;
  logic                       mailbox_data_val;

  int                         commit_count;

  logic  [               3:0] nmi_assert_int;

  logic                       wb_valid;
  logic  [               4:0] wb_dest;
  logic  [              31:0] wb_data;

  logic                       wb_csr_valid;
  logic  [              11:0] wb_csr_dest;
  logic  [              31:0] wb_csr_data;

  logic                       dmi_core_enable;
  string                      firmware0;
  string                      firmware1;

  always_comb dmi_core_enable = ~(o_cpu_halt_status);

  string abi_reg[32];  // ABI register names

  `define DEC top_guineveer.rvtop_wrapper0.veer.dec

  assign mailbox_write = top_guineveer.rvtop_wrapper0.lsu_axi_awvalid
    && top_guineveer.rvtop_wrapper0.lsu_axi_awaddr == mem_mailbox && rst_l;
  assign mailbox_data = top_guineveer.rvtop_wrapper0.lsu_axi_wdata;

  assign mailbox_data_val = mailbox_data[7:0] > 8'h5 && mailbox_data[7:0] < 8'h7f;

  integer fd, tp, el;
  logic next_dbus_error;
  logic next_ibus_error;

  always @(negedge core_clk) begin
    cycleCnt <= cycleCnt + 1;
  end

  always @(negedge core_clk or negedge rst_l) begin
    if (rst_l == 0) begin
      next_dbus_error <= '0;
      next_ibus_error <= '0;
    end else begin
      nmi_assert_int <= nmi_assert_int >> 1;
      soft_int <= 0;
      timer_int <= 0;
      extintsrc_req[1] <= 0;
      // timeout monitor
      if (cycleCnt == MAX_CYCLES) begin
        $display("Hit max cycle count (%0d) .. stopping", cycleCnt);
        $display("TEST_FAILED");
        $fatal;
      end
      // console Monitor
      if (mailbox_data_val & mailbox_write) begin
        $fwrite(fd, "%c", mailbox_data[7:0]);
        $write("%c", mailbox_data[7:0]);
      end

      if (mailbox_write && mailbox_data[7:0] == 8'hff) begin
        $display("\nFinished : minstret = %0d, mcycle = %0d", `DEC.tlu.minstretl[31:0],
                 `DEC.tlu.mcyclel[31:0]);
        $display("See \"exec.log\" for execution trace with register updates..\n");
        $display("VerilatorTB: End of sim\n");
        // OpenOCD test breaks if simulation closes the TCP connection first.
        // This delay allows OpenOCD to close the connection before the #finish.
        #15000;
        $finish(0);
      end else if (mailbox_write && mailbox_data[7:0] == 8'h1) begin
        $display("TEST_FAILED");
        $fatal;
      end
    end
  end

  // nmi_int must be asserted for at least two clock cycles and then deasserted for
  // at least two clock cycles - see RISC-V VeeR EL2 Programmer's Reference Manual section 2.16
  assign nmi_int = |{nmi_assert_int[3:2]};

  // trace monitor
  always @(posedge core_clk) begin
    wb_valid     <= `DEC.dec_i0_wen_r;
    wb_dest      <= `DEC.dec_i0_waddr_r;
    wb_data      <= `DEC.dec_i0_wdata_r;
    wb_csr_valid <= `DEC.dec_csr_wen_r;
    wb_csr_dest  <= `DEC.dec_csr_wraddr_r;
    wb_csr_data  <= `DEC.dec_csr_wrdata_r;
    if (trace_rv_i_valid_ip) begin
      $fwrite(tp, "%b,%h,%h,%0h,%0h,3,%b,%h,%h,%b\n", trace_rv_i_valid_ip, 0,
              trace_rv_i_address_ip, 0, trace_rv_i_insn_ip, trace_rv_i_exception_ip,
              trace_rv_i_ecause_ip, trace_rv_i_tval_ip, trace_rv_i_interrupt_ip);
      // Basic trace - no exception register updates
      // #1 0 ee000000 b0201073 c 0b02       00000000
      commit_count++;
      $fwrite(el, "%10d : %8s 0 %h %h%13s %14s ; %s\n", cycleCnt, $sformatf("#%0d", commit_count),
              trace_rv_i_address_ip, trace_rv_i_insn_ip, (wb_dest != 0 && wb_valid) ? $sformatf
              ("%s=%h", abi_reg[wb_dest], wb_data) : "            ", (wb_csr_valid) ? $sformatf
              ("c%h=%h", wb_csr_dest, wb_csr_data) : "             ", dasm(
              trace_rv_i_insn_ip, trace_rv_i_address_ip, wb_dest & {5{wb_valid}}, wb_data));
    end
    if (`DEC.dec_nonblock_load_wen) begin
      $fwrite(el, "%10d : %32s=%h                ; nbL\n", cycleCnt,
              abi_reg[`DEC.dec_nonblock_load_waddr], `DEC.lsu_nonblock_load_data);
      guineveer_tb.gpr[0][`DEC.dec_nonblock_load_waddr] = `DEC.lsu_nonblock_load_data;
    end
    if (`DEC.exu_div_wren) begin
      $fwrite(el, "%10d : %32s=%h                ; nbD\n", cycleCnt, abi_reg[`DEC.div_waddr_wb],
              `DEC.exu_div_result);
      guineveer_tb.gpr[0][`DEC.div_waddr_wb] = `DEC.exu_div_result;
    end
  end

  always #(15) core_clk = ~core_clk;  // 33.33MHz
  always #(2) i3c_clk = ~i3c_clk;  // 250MHz
  always @(posedge core_clk) $dumpvars();

  // startup
  initial begin
    $dumpfile("sim.vcd");

    $display("\nVerilatorTB: Start of sim\n");
    mem_signature_begin = '0;
    mem_signature_end = '0;
    mem_mailbox = 'h80f80000;

    $display("mem_mailbox = %x", mem_mailbox);

    abi_reg[0]     = "zero";
    abi_reg[1]     = "ra";
    abi_reg[2]     = "sp";
    abi_reg[3]     = "gp";
    abi_reg[4]     = "tp";
    abi_reg[5]     = "t0";
    abi_reg[6]     = "t1";
    abi_reg[7]     = "t2";
    abi_reg[8]     = "s0";
    abi_reg[9]     = "s1";
    abi_reg[10]    = "a0";
    abi_reg[11]    = "a1";
    abi_reg[12]    = "a2";
    abi_reg[13]    = "a3";
    abi_reg[14]    = "a4";
    abi_reg[15]    = "a5";
    abi_reg[16]    = "a6";
    abi_reg[17]    = "a7";
    abi_reg[18]    = "s2";
    abi_reg[19]    = "s3";
    abi_reg[20]    = "s4";
    abi_reg[21]    = "s5";
    abi_reg[22]    = "s6";
    abi_reg[23]    = "s7";
    abi_reg[24]    = "s8";
    abi_reg[25]    = "s9";
    abi_reg[26]    = "s10";
    abi_reg[27]    = "s11";
    abi_reg[28]    = "t3";
    abi_reg[29]    = "t4";
    abi_reg[30]    = "t5";
    abi_reg[31]    = "t6";

    extintsrc_req  = {pt.PIC_TOTAL_INT{1'b0}};
    timer_int      = 0;
    soft_int       = 0;

    // tie offs
    jtag_id[31:28] = '1;
    jtag_id[27:12] = '0;
    jtag_id[11:1]  = 11'h45;
    reset_vector   = `RV_RESET_VEC;
    nmi_assert_int = 0;
    nmi_vector     = 32'hee000000;
    lsu_bus_clk_en = 1;

    if ($value$plusargs("firmware0=%s", firmware0)) begin
      $readmemh(firmware0, top_guineveer.lmem0.xguineveer_sram.mem);
    end
    
`ifdef DUALCORE
    if ($value$plusargs("firmware1=%s", firmware1)) begin
      $readmemh(firmware1, top_guineveer.lmem1.xguineveer_sram.mem);
    end
`endif

    tp = $fopen("trace_port.csv", "w");
    el = $fopen("exec.log", "w");
    $fwrite(el,
            "//   Cycle : #inst    0    pc    opcode    reg=value    csr=value     ; mnemonic\n");
    fd = $fopen("console.log", "w");
    commit_count = 0;
  end
  assign rst_l = cycleCnt > 2;

  // UART monitor
  string line_buffer;
  logic [7:0] rx_data;
  logic rx_valid, idle, frame_err, rx_parity_err;

  uart_rx uart_monitor (
      .clk_i(core_clk),
      .rst_ni(rst_l),
      .rx_enable(top_guineveer.uart_core.uart_core.uart_core.rx_enable),
      .tick_baud_x16(top_guineveer.uart_core.uart_core.uart_core.uart_rx.tick_baud_x16),
      .parity_enable(top_guineveer.uart_core.uart_core.reg2hw.ctrl.parity_en.q),
      .parity_odd(top_guineveer.uart_core.uart_core.reg2hw.ctrl.parity_odd.q),
      .tick_baud(),
      .rx_valid,
      .rx_data,
      .idle,
      .frame_err,
      .rx_parity_err,
      .rx(top_guineveer.uart_tx_o)
  );

  always_ff @(posedge core_clk, negedge rst_l) begin
    if (!rst_l) line_buffer <= "";
    else if (frame_err) $error("[UART MONITOR]: Frame error");
    else if (rx_parity_err) $error("[UART MONITOR]: rx_parity_err");
    else if (rx_valid) begin
      if (rx_data == "\n") begin
        $display("[UART MONITOR]: %s", line_buffer);
        line_buffer <= "";
      end else line_buffer <= {line_buffer, rx_data};
    end
  end

  final if (line_buffer.len() > 0) $display("[UART MONITOR]: %s", line_buffer);

  guineveer top_guineveer (
      .clk_i(core_clk),
      .rst_ni(rst_l),
      .cpu_rst_ni(rst_l),

      .i3c_clk_i (i3c_clk),
      .i3c_rst_ni(rst_l),
      .i3c_scl_i,
      .i3c_sda_i,
      .i3c_scl_o,
      .i3c_sda_o,
      .i3c_scl_oe,
      .i3c_sda_oe,
      .i3c_sel_od_pp_o,

      .uart_rx_i(uart_rx),
      .uart_tx_o(uart_tx)
  );

  `include "dasm.svi"

endmodule
