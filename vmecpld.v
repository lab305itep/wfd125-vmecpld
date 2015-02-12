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
//					CSR4 (RW) Xilix Configuration select: 
//							0 - Xilinx Master (M=01, CPLD don't drive CCLK & DIN), 
//							1 - Xilinx Slave  (M=11, CCLK & DIN driven by CPLD), 
//							default 0, overriden by CSR1 (FLASH enable has priority)
//					CSR5 (RW) Xilinx PROG, 1 - PROG asserted, default 0
//					CSR6 (R)  Xilix INIT
//					CSR7 (R)  Xilix DONE, 1 - Configured
//		BASE+2: SDAT[7:0] (RW) Serial data register
//					W - any write causes generation of 8 SERCLK and shifts written data MSB first to FD0 (FLASH enabled) or FD1 (Xilinx slave)
//					R - after 8 FLASHCLK contains received data from FD1 (FLASH enabled) or undefined (Xilinx Slave)
//    BASE+4: SERIAL[7:0] (R) Serial Number, BASE=0xA000 + (SERIAL << 4)
//    BASE+6: BATCH[7:0] (R) Batch Number, informative, not decoded in address
//    BASE+8: C2X pins: C2X[4:0] "Geographic address assigned" - for VME CSR address space, C2X[7] - reset, active low
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
    output reg [7:0] C2X,
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
	// module addressed bits
	// all regs but SDAT
	reg ADS = 0;
	// SDAT
	reg ADS1 = 0;
	// clocked data strobe and delayed
	reg DDS = 0;
	reg DDST = 0;
	// Write and read strobes
	wire [NREGS-1:0] WS;
	wire [NREGS-1:0] RS;
	// CSR
	reg [7:0] CSR = 8'h00;
	// serial clock from shifter
	wire SERCLK;
	// serial data out from shifter
	wire SOUT;
	// serial tansmitter is BUSY shifting
	wire BUSY;
	
//	working frequency CPLDCLK/2
	CLK_DIV2 CLK_DIV_inst (
      .CLKDV(CLK),    	// Divided clock output
      .CLKIN(CPLDCLK)   // Clock input
   );
	assign TP[1] = ADS;
	assign TP[2] = DDS;
	assign TP[3] = XDTACK;
	assign TP[4] = XDTACKOE;
	assign TP[5] = DDIR;
	assign XIACKOUT = XIACKIN;

	// we are driving flash
	assign FENB = CSR[1];
	// we are driving Xilinx in slave mode (overriden by FENB)
	assign XENB = CSR[4] & !CSR[1];
	// Flash CS is driven by CSR0 when flash enabled
	assign FLASHCS = (FENB) ? !CSR[0] : 1'bz;
	// serial clock is driven by serial shifter both for flash and xilinx programming
	assign FLASHCLK = (FENB || XENB) ? SERCLK : 1'bz;
	// FD0 is driven by serial shifter when flash enabled
	assign FLASHD[0] = (FENB) ? SOUT : 1'bz;
	// FD1 is driven by serial shifter when xilinx enabled
	assign FLASHD[1] = (XENB) ? SOUT : 1'bz;
	// keep WP and HOLD HIGH
	assign FLASHD[3:2] = 2'bZZ;
	// serial input is always connected to FD1
	assign SIN = FLASHD[1];
	// Xilinx prog pin (asserted when CSR5=1), will automatically be pulled on POR
	assign PROG = (CSR[5] || !CRST) ? 0 : 1'bz;
	// Xilinx M pins (SPI master bu default, slave serial when CPL is programming Xilinx)
	assign M = (XENB) ? 2'b11 : 2'b01;
	
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
	// CSR or SERIAL# or BATCH#
	assign XD = (RS[0]) ? {DONE, INIT, CSR[5:0]} : ((RS[2]) ? SERIAL : ((RS[3]) ? BATCH : ((RS[4]) ? C2X : 8'hzz)));

  always @(posedge CLK) begin
	// on POR
	if (!CRST) begin
		CSR <= 0;
		ADS <= 0;
		ADS1 <= 0;
		DDS <= 0;
		DDST <= 0;
		C2X <= 0;
	end
	else begin
		// if regular A16 address matches
		if (!XAS && (XAM == 6'h2D || XAM == 6'h29) && XIACK && XA[0] && XA[15:4] == (12'hA00 + SERIAL) ) begin
			if (XA[3:2] == 0) ADS1 <= 1;		// separate ADS for SDAT and CSR (not to change FLASHCS during transfers)
			else ADS <= 1;
		end
		// if DS0 asserted (ignore DS1)
		if (!XDS[0]) begin
			// delay operations and DTACK for SDAT and CSR in case prev transfer has not ended
			if ((ADS || (ADS1 && !BUSY)) && !DDS) begin
				DDS <= 1;
			end
		end 
		else begin
			DDS <= 0;
		end
		// delayed DDS
		DDST <= DDS;
		// finish cycle at trailing edge of DS0
		if (DDST && !DDS) begin
			ADS <= 0;
			ADS1 <= 0;
		end
		
		// write CSR
		if (WS[0]) begin
			CSR <= XD;
		end
	   // write C2X
		if (WS[4]) begin
			C2X <= XD;
		end
	end
  end
	
	// serial shift registers module
	serial_io SERIALIO (
		.CLK(CLK),
		.WS(WS[1]),
		.RS(RS[1]),
		.DATA(XD),
		.SI(SIN),
		.SO(SOUT),
		.FCK(SERCLK),
		.BUSY(BUSY)
    );

endmodule
