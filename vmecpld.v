`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: ITEP
// Engineer: SvirLex
// 
// Create Date:    19:11:52 09/01/2014 
// Design Name: 
// Module Name:    vmecpld 
// Project Name:   wfd125
// Target Devices: xc2c128-7-VQ100
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
// Registers:
//		BASE+0: CSR[7:0] (RW) Control & Status register
//					CSR0 (RW) FLASH_CS, 1 - CS asserted if FLASH enabled, default 0
//					CSR1 (RW) FLASH_ENB, 1 - FLASH access enabled from CPLD side, default 0
//					CSR4 (RW) Xilix Configuration select, 0 - Xilinx Master (M=01, CPLD don't drive CCLK & DIN), 1 - Xilinx Slave (M=11, CCLK & DIN ENABLED), default 0
//					CSR5 (RW) Xilinx PROG, 1 - PROG asserted, default 0
//					CSR6 (R)  Xilix INIT
//					CSR7 (R)  Xilix DONE, 1 - Configured
//		BASE+2: FDAT[7:0] (RW) Flash serial data register
//					W - any write causes generation of 8 FLASHCLK and shifts written data to FD0 MSB first
//					R - after 8 FLASHCLK contains received data from FD1
//		BASE+4: XDAT[7:0] (W) Xilinx serial data register
//					W - any write causes generation of 8 CCLK and shifts written data to DIN
//					R - always reads 0
//    BASE+6: SERIAL[7:0] (R) Serial Number, BASE=0xA000 + (SERIAL << 4)
//    BASE+8: BATCH[7:0] (R) Batch Number, informative, not decoded in address
//
//
//////////////////////////////////////////////////////////////////////////////////



module vmecpld(
    inout [7:0] XD,
    input [15:0] XA,
    input [5:0] XAM,
    input [5:0] XGA,
    input XAS,
    input [1:0] XDS,
    input XWRITE,
    input XRESET,
    input IACKPASS,
    input XIACK,
    input XIACKIN,
    output XIACKOUT,
    output XDTACK,
    output XDTACKOE,
    output DDIR,
	 input CPLDCLK,
    input CRST,
    output [5:1] TP,
    output FLASHCLK,
    input FLASHCS,
    inout [3:0] FLASHD,
    input [7:0] C2X,
    output [1:0] M,
    input DONE,
    output PROG,
    input INIT
    );

`include "serial.vh"
localparam NREGS = 5;

	wire CLK;
	reg [7:0] CSR = 8'h00;
	reg ADS = 0;
	reg DDS = 0;
	reg DDST = 0;
	wire [NREGS-1:0] WS;
	wire [NREGS-1:0] RS;
	
	assign CLK = CPLDCLK;
	assign TP[1] = ADS;
	assign TP[2] = DDS;
	assign TP[3] = XDTACK;
	assign TP[4] = XDTACKOE;
	assign TP[5] = DDIR;

	assign M = 2'b11;
	assign PROG = 1'b1;
	assign FLASHCLK = 1'bz;
	assign XIACKOUT = XIACKIN;
	assign FLASHD = 4'hz;
	assign XDTACK = (DDS) ? 0 : ( (DDST) ? 1 : 1'bz);
	assign XDTACKOE = (DDS || DDST) ? 0 : 1'bz;
	assign DDIR = (DDS && XWRITE) ? 1 : 1'bz;

	genvar i;
   generate
      for (i=0; i < NREGS; i=i+1) 
      begin: GWS
         assign WS[i] = !XWRITE && !DDST && DDS && (XA[3:1] == i);
			assign RS[i] = DDS && XWRITE && (XA[3:1] == i);
      end
   endgenerate

	assign XD = (RS[0]) ? {CSR} : 8'hzz;
	assign XD = (RS[3]) ? {SERIAL} : 8'hzz;
	assign XD = (RS[4]) ? {BATCH} : 8'hzz;
	

	always @(posedge CLK) begin
		if (!XAS && (XAM == 6'h2D || XAM == 6'h29) && XIACK && XA[0] && XA[15:4] == (12'hA00 + SERIAL) ) ADS <= 1;
		if (ADS && !XDS[0]) begin
			DDS <= 1;
		end else begin
			DDS <= 0;
		end
		DDST <= DDS;
		if (DDST && !DDS) begin
			ADS <= 0;
		end
		if (WS[0]) begin
			CSR <= XD;
		end
	end
	
	flash_io FLASHIO (
		.CLK(CLK),
		.ENABLE(CSR[1]),
		.WS(WS[1]),
		.RS(RS[1]),
		.DATA(XD),
		.SI(FLASHD[1]),
		.SO(FLASHD[0]),
		.FCK(FLASHCLK)
    );

endmodule
