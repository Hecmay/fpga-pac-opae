// Copyright 2016 Altera Corporation. All rights reserved.
// Altera products are protected under numerous U.S. and foreign patents, 
// maskwork rights, copyrights and other intellectual property laws.  
//
// This reference design file, and your use thereof, is subject to and governed
// by the terms and conditions of the applicable Altera Reference Design 
// License Agreement (either as signed by you or found at www.altera.com).  By
// using this reference design file, you indicate your acceptance of such terms
// and conditions between you and Altera Corporation.  In the event that you do
// not agree with such terms and conditions, you may not use the reference 
// design file and please promptly destroy any copies you have made.
//
// This reference design file is being provided on an "as-is" basis and as an 
// accommodation and therefore all warranties, representations or guarantees of 
// any kind (whether express, implied or statutory) including, without 
// limitation, warranties of merchantability, non-infringement, or fitness for
// a particular purpose, are specifically disclaimed.  By making this reference
// design file available, Altera expressly does not recommend, suggest or 
// require that this reference design file be used in combination with any 
// other product not provided by Altera.
/////////////////////////////////////////////////////////////////////////////


`timescale 1ps/1ps

// DESCRIPTION
// JTAG chain access shift register.
// Generated by one of Gregg's toys.   Share And Enjoy.

module alt_jtagsr #(
	parameter   NODE_ID = 8'h33,
	parameter   INSTANCE_ID = 8'h0,
	parameter   NODE_VERSION = 5'h02,
    parameter   SLD_NODE_INFO = {NODE_VERSION[4:0],NODE_ID[7:0],11'h06E,INSTANCE_ID[7:0]},
                         // node_ver[31:27], node_id[26:19], mfg_id[18:8], inst_id[7:0]
    parameter   SLD_AUTO_INSTANCE_INDEX = "YES",
    parameter   NODE_IR_WIDTH = 1,
    parameter   DAT_WIDTH = 24,
    parameter   SIM_EMULATE = 1'b0
)
(
	// Hub sigs
	// connected by Quartus
	input       raw_tck,                // raw node clock;
	input       tdi,                    // node data in;
	input       usr1,                   // Indicates that current instruction in the JSM is the USER1 instruction;
	input       clrn,                   // Asynchronous clear;
	input       ena,                    // Indicates that the current instruction in the Hub is for Node
	input       [NODE_IR_WIDTH-1:0] ir_in,  // Node IR;
	output      tdo,                    // Node data out
	output      [NODE_IR_WIDTH-1:0] ir_out, // Node IR capture port
	input       jtag_state_cdr,         // Indicates that the JSM is in the Capture_DR(CDR) state;
	input       jtag_state_sdr,         // Indicates that the JSM is in the Shift_DR(SDR) state;
	input       jtag_state_udr,         // Indicates that the JSM is in the Update_DR(UDR) state;

	// internal sigs 
	// data to and from host PC
	input core_clk,

	input [18:0] dat_to_jtag_reg,
	input dat_to_jtag_stable_reg,
	
	output reg [15:0] cmd,
	output reg [15:0] addr,
	output reg [31:0] dout,
	output reg fresh_cmd,
	output reg fresh_dout
);

initial cmd = 16'h0;
initial addr = 16'h0;
initial dout = 32'h0;
initial fresh_cmd = 1'b0;
initial fresh_dout = 1'b0;

assign ir_out = ir_in;

reg [DAT_WIDTH-1:0] sr;
wire dr_select = ena & ~usr1;

reg	[18:0] dat_from_jtag_i;
reg	dat_from_jtag_valid_i;

wire [18:0] dat_to_jtag_i;
wire dat_to_jtag_stable_i;

/////////////////////////////////////////
// shift out data from FPGA to JTAG host
/////////////////////////////////////////

always @(posedge raw_tck or negedge clrn) begin
	if (!clrn) begin
		sr <= 0;
	end
	else begin
		if (dr_select) begin
			if (jtag_state_cdr) begin
				sr <= dat_to_jtag_stable_i ? {5'b10101,dat_to_jtag_i} :
					 {DAT_WIDTH{1'b0}}; // send 0 if unstable
			end

			if (jtag_state_sdr) begin
				sr <= {tdi,sr[DAT_WIDTH-1:1]};
			end			
		end
		else begin
			sr[0] <= tdi;
		end		
	end
end
assign tdo = sr[0];

////////////////////////////////////
// grab data from JTAG host to FPGA
////////////////////////////////////

reg dat_from_jtag_sane = 1'b0;
always @(posedge raw_tck or negedge clrn) begin
	if (!clrn) begin
		dat_from_jtag_valid_i <= 1'b0;
		dat_from_jtag_i <= 19'b0;
		dat_from_jtag_sane <= 1'b0;
	end
	else begin
		dat_from_jtag_valid_i <= 1'b0;
		if (dr_select & jtag_state_udr) begin
			dat_from_jtag_i <= sr[18:0];
			dat_from_jtag_valid_i <= 1'b1;
			dat_from_jtag_sane <= (sr[23:19] == 5'b10101);
		end
	end
end

reg dat_from_jtag_stable_i = 1'b0;
reg dat_from_jtag_stable_ii = 1'b0;
always @(posedge raw_tck) begin
	dat_from_jtag_stable_i <= dat_from_jtag_valid_i && dat_from_jtag_sane;
	dat_from_jtag_stable_ii <= dat_from_jtag_stable_i;
end

////////////////////////////////////
// cross clocks between FPGA to JTAG
////////////////////////////////////

wire [18:0] dat_from_jtag;
wire dat_from_jtag_stable;
alt_sync20m sn0 (
    .din_clk(raw_tck),
    .din({dat_from_jtag_stable_ii,dat_from_jtag_i}),
    .dout_clk(core_clk),
    .dout({dat_from_jtag_stable,dat_from_jtag})
);
defparam sn0 .SIM_EMULATE = SIM_EMULATE;

alt_sync20m sn1 (
    .din_clk(core_clk),
    .din({dat_to_jtag_stable_reg,dat_to_jtag_reg}),
    .dout_clk(raw_tck),
    .dout({dat_to_jtag_stable_i,dat_to_jtag_i})
);
defparam sn1 .SIM_EMULATE = SIM_EMULATE;


////////////////////////////////////
// expand the from JTAG info
////////////////////////////////////

reg last_dat_from_jtag_stable = 1'b0;

always @(posedge core_clk) begin
	last_dat_from_jtag_stable <= dat_from_jtag_stable;
	
	if (dat_from_jtag_stable) begin
		if (dat_from_jtag[17:16] == 2'b00) cmd <= dat_from_jtag[15:0];
		if (dat_from_jtag[17:16] == 2'b01) addr <= dat_from_jtag[15:0];
		if (dat_from_jtag[17:16] == 2'b10) dout[15:0] <= dat_from_jtag[15:0];
		if (dat_from_jtag[17:16] == 2'b11) dout[31:16] <= dat_from_jtag[15:0];
	end
	
	fresh_cmd <= !last_dat_from_jtag_stable && dat_from_jtag_stable && 
				(dat_from_jtag[17:16] == 2'b00);
	fresh_dout <= !last_dat_from_jtag_stable && dat_from_jtag_stable && 
				(dat_from_jtag[17:16] == 2'b10);		
	
	if (fresh_dout && cmd[0]) addr <= addr + 4'h4;
end

endmodule
