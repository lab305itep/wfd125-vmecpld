`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: ITEP
// Engineer: SvirLex
// 
// Create Date:    19:11:52 09/01/2014 
// Design Name:    vmecpld
// Module Name:    vmecpld 
// Project Name:   wfd125
// Target Devices: xc2c128-7-VQ100
//
// Revision 0.01 - File Created
// Additional Comments: 
//
// Registers: to be read/written as lower (odd) bytes with A16/D16 transfers
//
//		BASE = A000 + (SERIAL << 4)
//
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
		// VME DATA (lower 8 bits)
    inout [7:0] XD,
		// VME ADDR (lower 16 bits)
    input [15:0] XA,
		// VME address modifier
    input [5:0] XAM,
		// VME geographical address (useless so far)
    input [5:0] XGA,
		// VME address strobe
    input XAS,
		// VME data strobes
    input [1:0] XDS,
		// VME write (low)
    input XWRITE,
		// VME reset (low)
    input XRESET,
		// interrupt service (inactive so far)
    input IACKPASS,
    input XIACK,
    input XIACKIN,
    output XIACKOUT,
		// VME data acknowledge (low)
    output XDTACK,
		// enable DTACK from tristate (low)
    output XDTACKOE,
		// buffer data direction (output to VME -- low)
    output DDIR,
		// 125 MHz clock
	 input CPLDCLK,
		// power-on reset
    input CRST,
		// test points
    output [5:1] TP,
		// FLASH clock
    output FLASHCLK,
		// FLASH select (low)
    output FLASHCS,
		// FLASH data
    inout [3:0] FLASHD,
		// connection to main FPGA
    input [7:0] C2X,
		// configuration mode to main FPGA
    output [1:0] M,
		// DONE from FPGA chain
    input DONE,
		// PROG to FPGA chain
    output PROG,
		// INIT from FPGA chain
    input INIT
    );

// serial and butch numbers (externally generated)
`include "serial.vh"

// Current number of active registers (<= 8)
localparam NREGS = 5;

	wire CLK;
	// module addressed bit
	reg ADS = 0;
	// clocked data strobe and delayed
	reg DDS = 0;
	reg DDST = 0;
	// Write and read strobes
	wire [NREGS-1:0] WS;
	wire [NREGS-1:0] RS;
	// CSR
	reg [7:0] CSR = 8'h00;
	
	assign CLK = CPLDCLK;
	assign TP[1] = ADS;
	assign TP[2] = DDS;
	assign TP[3] = XDTACK;
	assign TP[4] = XDTACKOE;
	assign TP[5] = DDIR;

	assign M = 2'b11;
	assign PROG = 1'b1;
	assign XIACKOUT = XIACKIN;

	// Flash CS is driven by CSR0 when enabled
	assign FLASHCS = (CSR[1]) ? !CSR[0] : 1'bz;
	// keep WP and HOLD HIGH
	assign FLASHD[3:2] = 2'b11;
	
	// reply with DTACK=0 to DS0, leave driven as 1 one CLK after deasserting
	assign XDTACK = (DDS) ? 0 : ( (DDST) ? 1 : 1'bz);
	assign XDTACKOE = (DDS || DDST) ? 0 : 1'bz;
	// buffer direction OUT on read operations
	assign DDIR = (DDS && XWRITE) ? 1 : 1'bz;

	// generate rad and write strobes
	genvar i;
   generate
      for (i=0; i < NREGS; i=i+1) 
      begin: GWS
			// write strobe is 1 CLK on leading edge of DS0
         assign WS[i] = !XWRITE && !DDST && DDS && (XA[3:1] == i);
			// read strobe is for the whole duration of DS0
			assign RS[i] = XWRITE && DDS && (XA[3:1] == i);
      end
   endgenerate

// Read registers in this top module
	// CSR
	assign XD = (RS[0]) ? {CSR} : 8'hzz;
	// Serial number
	assign XD = (RS[3]) ? {SERIAL} : 8'hzz;
	// Batch number
	assign XD = (RS[4]) ? {BATCH} : 8'hzz;
	

	always @(posedge CLK) begin
		
		// if regular A16 address matches
		if (!XAS && (XAM == 6'h2D || XAM == 6'h29) && XIACK && XA[0] && XA[15:4] == (12'hA00 + SERIAL) ) ADS <= 1;
		// if DS0 asserted (ignore DS1)
		if (ADS && !XDS[0]) begin
			DDS <= 1;
		end else begin
			DDS <= 0;
		end
		// delayed DDS
		DDST <= DDS;
		// finish cycle at trailing edge of DS0
		if (DDST && !DDS) begin
			ADS <= 0;
		end
		
		// write CSR
		if (WS[0]) begin
			CSR <= XD;
		end
		
	end
	
	// Flash connection module
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
