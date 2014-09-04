`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: ITEP
// Engineer: SvirLex
// 
// Create Date:    19:11:52 09/01/2014 
// Design Name:    vmecpld
// Module Name:    flash_io 
// Project Name:   wfd125
// Target Devices: xc2c128-7-VQ100
//
// Revision 0.01 - File Created
// Additional Comments: 
//		On write to data register, generates 8 FCLK pulses, shifts output data
// 	on negative edges, latches input data on positive edges
//
//////////////////////////////////////////////////////////////////////////////////
module flash_io(
		// sustem clock 125 MHz
    input CLK,
		// 1 if CPLD is flash master
    input ENABLE,
		// data write strobe
    input WS,
		// data read strobe
    input RS,
		// data lines to VME
    inout [7:0] DATA,
		// serial input from FLASH
	 input SI,
		// serial output to FLASH
	 output SO,
		// serial clock to FLASH
	 output FCK
    );

	// Output shift register
	reg [7:0] OSREG = 0;
	// input shift register
	reg [7:0] ISREG = 0;
	// serial clock, inactive high, CLK/2 = 62.5 MHz
	reg FCLK = 1;
	// state machine variable
	reg [3:0] i = 0;

	// read serial input register
	assign DATA = (RS) ? ISREG : 8'hzz;
	// serial data MSB first, when enabled
	assign SO = (ENABLE) ? OSREG[7] : 1'bz;
	// serial clock, when enabled
	assign FCK = (ENABLE) ? FCLK : 1'bz;
	
	always @(posedge CLK) begin
		// start on write to data register
		if (i == 0) begin
			if (WS) begin 
				// set data, first FCLK 1->0 transition
				OSREG <= DATA;
				FCLK <= 0;
				i <= 1;
			end
		end
		// odd transitions 0->1, latch input MSB first
		// 1 3 5 7 9 11 13 15
		else if (i[0]) begin
			ISREG <= {ISREG[7:1], SI}; 
			FCLK <= 1;
			if (i == 15) i <= 0;
			else i <= i+1;
		end
		// even transitions 1->0, change output MSB first
		// 2 4 6 8 10 12 14
		else begin
			OSREG <= {OSREG[6:0], 0};
			FCLK <= 0;
			i <= i+1;
		end
		

	end

endmodule
