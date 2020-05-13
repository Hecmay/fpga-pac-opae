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
// 8:1 MUX of 1 bit words.  Latency 2.  Select latency 1.
// Generated by one of Gregg's toys.   Share And Enjoy.

module alt_mux8w1t2s1 #(
    parameter SIM_EMULATE = 1'b0
) (
    input clk,
    input [7:0] din,
    input [2:0] sel,
    output dout
);

wire [1:0] head_din;
wire head_sel = sel[2];

alt_mux4w1t1s1 mx0 (
    .clk(clk),
    .din(din[3:0]),
    .sel(sel[1:0]),
    .dout(head_din[0:0])
);
defparam mx0 .SIM_EMULATE = SIM_EMULATE;

alt_mux4w1t1s1 mx1 (
    .clk(clk),
    .din(din[7:4]),
    .sel(sel[1:0]),
    .dout(head_din[1:1])
);
defparam mx1 .SIM_EMULATE = SIM_EMULATE;

alt_mux2w1t1s2 mx2 (
    .clk(clk),
    .din(head_din),
    .sel(head_sel),
    .dout(dout)
);
defparam mx2 .SIM_EMULATE = SIM_EMULATE;

endmodule
