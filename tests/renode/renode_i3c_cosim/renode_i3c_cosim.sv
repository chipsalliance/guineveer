//
//  Copyright 2025-2026 Antmicro
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

`timescale 1ns / 1ps

import renode_pkg::renode_runtime;

module sim;
  parameter int unsigned AXIDataWidth = 64;
  parameter int unsigned AXIAddrWidth = 20;
  parameter int AXISubIdWidth = 4;
  parameter int ClockPeriod = 100;

  parameter int unsigned RenodeToCosimCount = 1;
  parameter int unsigned CosimToRenodeCount = 0;

  logic clk = 1;

  logic [4:0] renode_inputs;
  logic [0:0] renode_outputs;

  renode_runtime runtime = new(RenodeToCosimCount, CosimToRenodeCount);
  renode #(
      .RenodeInputsCount(5),
      .RenodeOutputsCount(1),
      .RenodeToCosimCount(1)
  ) renode (
      .runtime(runtime),
      .clk(clk),
      .renode_inputs(renode_inputs),
      .renode_outputs(renode_outputs)
  );

  renode_axi_if #(.AddressWidth(AXIAddrWidth), .DataWidth(AXIDataWidth)) axi (clk);
  renode_axi_manager renode_axi_manager (
      .runtime(runtime),
      .bus(axi)
  );

  initial begin
    runtime.connect_plus_args();
    renode.reset();
  end

  always @(posedge clk) begin
    renode.receive_and_handle_message();
    if (!runtime.is_connected()) $finish;
  end

  always #(ClockPeriod / 2) clk = ~clk;

  // Unused signals
  wire i3c_axi_ruser_unused;
  wire i3c_axi_buser_unused;
  wire scl_i;
  wire sda_i;
  wire scl_o;
  wire sda_o;
  wire scl_oe;
  wire sda_oe;
  wire sel_od_pp_o;

  `RENODE_I3C_WRAPPER #(
      .AxiAddrWidth(AXIAddrWidth),
      .AxiDataWidth(AXIDataWidth),
      .AxiUserWidth(1),
      .AxiIdWidth(AXISubIdWidth)
  ) i3c_core (
      .clk_i (clk),
      .rst_ni(axi.areset_n),

      .araddr_i(axi.araddr),
      .arburst_i(axi.arburst),
      .arsize_i(axi.arsize),
      .arlen_i(axi.arlen),
      .aruser_i('0),
      .arid_i(axi.arid),
      .arlock_i(axi.arlock),
      .arvalid_i(axi.arvalid),
      .arready_o(axi.arready),

      .rdata_o(axi.rdata),
      .rresp_o(axi.rresp),
      .rid_o(axi.rid),
      .ruser_o(i3c_axi_ruser_unused),
      .rlast_o(axi.rlast),
      .rvalid_o(axi.rvalid),
      .rready_i(axi.rready),

      .awaddr_i(axi.awaddr),
      .awburst_i(axi.awburst),
      .awsize_i(axi.awsize),
      .awlen_i(axi.awlen),
      .awuser_i('0),
      .awid_i(axi.awid),
      .awlock_i(axi.awlock),
      .awvalid_i(axi.awvalid),
      .awready_o(axi.awready),

      .wdata_i(axi.wdata),
      .wstrb_i(axi.wstrb),
      .wuser_i('0),
      .wlast_i(axi.wlast),
      .wvalid_i(axi.wvalid),
      .wready_o(axi.wready),

      .bresp_o(axi.bresp),
      .bid_o(axi.bid),
      .buser_o(i3c_axi_buser_unused),
      .bvalid_o(axi.bvalid),
      .bready_i(axi.bready),

      .disable_id_filtering_i('1),
      .priv_ids_i(),

      .scl_i(scl_i),
      .sda_i(sda_i),
      .scl_o(scl_o),
      .sda_o(sda_o),
      .scl_oe(scl_oe),
      .sda_oe(sda_oe),
      .sel_od_pp_o(sel_od_pp_o),

      .recovery_payload_available_o(renode_inputs[0]),
      .recovery_image_activated_o(renode_inputs[1]),

      .peripheral_reset_o(renode_inputs[2]),
      .peripheral_reset_done_i(renode_outputs[0]),
      .escalated_reset_o(renode_inputs[3]),

      .irq_o(renode_inputs[4])
  );
endmodule
