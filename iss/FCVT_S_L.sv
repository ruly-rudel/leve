
`include "defs.vh"

module FCVT_S_L
#(
	parameter	F_WIDTH = 32,
	parameter	F_EXP   = 8,
	parameter	F_FLAC  = 23,
	parameter	I_WIDTH = 64
)
(
	input [I_WIDTH-1:0]		in1,
	output logic [F_WIDTH-1:0]	out1,

	output logic			inexact
);

	logic 				sign_1;
	logic				is_zero_1;
	logic [I_WIDTH-1:0]		abs_1;


	logic [5:0]			sft_amt_1;
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
		sft_amt_1  = first_1_64(abs_1);
		sft_flac_1 = abs_1 << sft_amt_1;

		// round
		rnd_flac_1 = sft_flac_1[I_WIDTH-2:I_WIDTH-F_FLAC-1];

		exp_1      = 'd127 + 'h3f - {2'h0, sft_amt_1};
		flac_1     = rnd_flac_1;

		out1 = is_zero_1 ? {F_WIDTH{1'b0}} : {sign_1, exp_1, flac_1};

		inexact = is_zero_1         ? 1'b0 :
			 |sft_flac_1[I_WIDTH-F_FLAC-2:0] ? 1'b1 : 1'b0;
	end

endmodule

