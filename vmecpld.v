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

	wire CLK;
	reg [7:0] DATA = 8'h00;
	reg ADS = 1'b0;
	reg DDS = 1'b0;
	reg DDST = 1'b0;
	
	assign CLK = CPLDCLK;
	assign TP[1] = ADS;
	assign TP[2] = DDS;
	assign TP[3] = XDTACK;
	assign TP[4] = XDTACKOE;
	assign TP[5] = DDIR;
//	assign TP[5:2] = DATA[3:0];
	assign M = 2'b11;
	assign PROG = 1'b1;
	assign FLASHCLK = 1'bz;
	assign XIACKOUT = XIACKIN;
	assign FLASHD = 4'hz;
	assign XDTACK = !DDS;
	assign XDTACKOE = !(DDS || DDST);
	assign XD = (DDS && XWRITE) ? DATA : 8'hzz;
	assign DDIR = (DDS && XWRITE) ? 1'b1 : 1'bz;

	

	always @(posedge CLK) begin
		if (XAS == 1'b0 && ( XAM == 6'h2D || XAM == 6'h29 ) && XIACK == 1'b1 && XA[15:4] == 12'h179) ADS <= 1'b1;
		if (ADS == 1'b1 && XDS[0] == 1'b0) begin
			DDS <= 1'b1;
		end else begin
			DDS <= 1'b0;
		end
		DDST <= DDS;
		if (DDST == 1'b1 && DDS == 1'b0) begin
			ADS <= 1'b0;
		end
		if (XWRITE == 1'b0 && DDST == 1'b0 && DDS == 1'b1) begin
			DATA <= XD;
		end
	end

endmodule
