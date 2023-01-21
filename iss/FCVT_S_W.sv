
`include "defs.vh"

function [4:0] first_1_32(input [31:0] in);
begin
	if(in[31])                      first_1_32 = 5'h00;
	else if (~in[31] && in[30])     first_1_32 = 5'h01;
	else if (~|in[31:30] && in[29]) first_1_32 = 5'h02;
	else if (~|in[31:29] && in[28]) first_1_32 = 5'h03;
	else if (~|in[31:28] && in[27]) first_1_32 = 5'h04;
	else if (~|in[31:27] && in[26]) first_1_32 = 5'h05;
	else if (~|in[31:26] && in[25]) first_1_32 = 5'h06;
	else if (~|in[31:25] && in[24]) first_1_32 = 5'h07;
	else if (~|in[31:24] && in[23]) first_1_32 = 5'h08;
	else if (~|in[31:23] && in[22]) first_1_32 = 5'h09;
	else if (~|in[31:22] && in[21]) first_1_32 = 5'h0a;
	else if (~|in[31:21] && in[20]) first_1_32 = 5'h0b;
	else if (~|in[31:20] && in[19]) first_1_32 = 5'h0c;
	else if (~|in[31:19] && in[18]) first_1_32 = 5'h0d;
	else if (~|in[31:18] && in[17]) first_1_32 = 5'h0e;
	else if (~|in[31:17] && in[16]) first_1_32 = 5'h0f;
	else if (~|in[31:16] && in[15]) first_1_32 = 5'h10;
	else if (~|in[31:15] && in[14]) first_1_32 = 5'h11;
	else if (~|in[31:14] && in[13]) first_1_32 = 5'h12;
	else if (~|in[31:13] && in[12]) first_1_32 = 5'h13;
	else if (~|in[31:12] && in[11]) first_1_32 = 5'h14;
	else if (~|in[31:11] && in[10]) first_1_32 = 5'h15;
	else if (~|in[31:10] && in[ 9]) first_1_32 = 5'h16;
	else if (~|in[31: 9] && in[ 8]) first_1_32 = 5'h17;
	else if (~|in[31: 8] && in[ 7]) first_1_32 = 5'h18;
	else if (~|in[31: 7] && in[ 6]) first_1_32 = 5'h19;
	else if (~|in[31: 6] && in[ 5]) first_1_32 = 5'h1a;
	else if (~|in[31: 5] && in[ 4]) first_1_32 = 5'h1b;
	else if (~|in[31: 4] && in[ 3]) first_1_32 = 5'h1c;
	else if (~|in[31: 3] && in[ 2]) first_1_32 = 5'h1d;
	else if (~|in[31: 2] && in[ 1]) first_1_32 = 5'h1e;
	else if (~|in[31: 1] && in[ 0]) first_1_32 = 5'h1f;
	else                            first_1_32 = 5'h00;	// zero
end
endfunction

module FCVT_S_W
#(
	parameter	F_WIDTH = 32,
	parameter	F_EXP   = 8,
	parameter	F_FLAC  = 23,
	parameter	I_WIDTH = 32
)
(
	input [I_WIDTH-1:0]		in1,
	output logic [F_WIDTH-1:0]	out1,

	output logic			inexact
);

	logic 				sign_1;
	logic				is_zero_1;
	logic [I_WIDTH-1:0]		abs_1;


	logic [4:0]			sft_amt_1;
	logic [I_WIDTH-1:0]		sft_flac_1;

	logic [F_FLAC-1:0]		rnd_flac_1;

	logic [F_EXP-1:0]		exp_1;
	logic [F_FLAC-1:0]		flac_1;

	always_comb begin
		// parse
		sign_1     = in1[I_WIDTH-1];
		is_zero_1  = ~|in1;

		// abs
		abs_1      = sign_1 ? ~in1 + 1'b1 : in1;

		// shift
		sft_amt_1  = first_1_32(abs_1);
		sft_flac_1 = abs_1 << sft_amt_1;

		// round
		rnd_flac_1 = sft_flac_1[I_WIDTH-2:I_WIDTH-F_FLAC-1];

		exp_1      = 'd127 + 'h1f - {3'h0, sft_amt_1};
		flac_1     = rnd_flac_1;

		out1 = is_zero_1 ? {F_WIDTH{1'b0}} : {sign_1, exp_1, flac_1};

		inexact = is_zero_1         ? 1'b0 :
			 |sft_flac_1[I_WIDTH-F_FLAC-2:0] ? 1'b1 : 1'b0;
	end

endmodule

