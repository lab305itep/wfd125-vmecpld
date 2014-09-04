`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    14:08:52 09/04/2014 
// Design Name: 
// Module Name:    flash_io 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module flash_io(
    input CLK,
    input ENABLE,
    input WS,
    input RS,
    inout [7:0] DATA,
	 input SI,
	 output SO,
	 output FCK
    );

	reg [7:0] OSREG;

	assign DATA = (RS) ? OSREG : 8'hzz;
	
	always @(posedge CLK) begin
		if (WS) OSREG <= DATA;
	end

endmodule
