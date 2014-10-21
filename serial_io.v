`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: ITEP
// Engineer: SvirLex
// 
// Create Date:    19:11:52 09/01/2014 
// Design Name:    vmecpld
// Module Name:    serial_io 
// Project Name:   wfd125
// Target Devices: xc2c128-7-VQ100
//
// Revision 0.01 - File Created
// Additional Comments: 
//		On write to data register, generates 8 FCLK pulses, shifts output data
// 	on negative edges, latches input data on the next negative edge edges
//    FCLK frequency is CLK/2
//
//////////////////////////////////////////////////////////////////////////////////
module serial_io(
		// system clock 125 MHz
    input CLK,
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
	 output reg FCK,
		// shifting in progress
	 output reg BUSY
    );

	// Output shift register
	reg [7:0] OSREG = 0;
	// input shift register
	reg [7:0] ISREG = 0;
	// state machine variable
	reg [5:0] i = 0;

	// read serial input register
	assign DATA = (RS) ? ISREG : 8'hzz;
	// serial data MSB first
	assign SO = OSREG[7];
	
	always @(posedge CLK) begin
		// start on write to data register
		if (i == 0) begin
			if (WS) begin 
				// set data, first FCLK 1->0 transition
				OSREG <= DATA;
				FCK <= 0;
				BUSY <= 1;
				i <= 1;
			end
			else begin
				FCK <= 1;
				BUSY <= 0;
			end
		end
		// odd transitions 0->1, latch input MSB first
		// 2 6 10 14 18 22 26 30 
		else if (i[1:0] == 2'b10) begin
			FCK <= 1;
			i <= i+1;
		end
		// even transitions 1->0, change output MSB first
		// 4 8 12 16 20 24 28 32
		else if (i[1:0] == 2'b00) begin
			OSREG <= {OSREG[6:0], 1'b0};
			ISREG <= {ISREG[6:0], SI}; 
			if (i == 32) begin
				i <= 0;
			end else begin
				FCK <= 0;
				i <= i+1;
			end
		end else begin
			i <= i+1;
		end
	end

endmodule
