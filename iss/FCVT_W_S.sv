
`include "defs.vh"

module FCVT_W_S
#(
	parameter	F_WIDTH = 32,
	parameter	F_EXP   = 8,
	parameter	F_FLAC  = 23,
	parameter	I_WIDTH = 32
)
(
	input [F_WIDTH-1:0]		in1,
	output logic [I_WIDTH-1:0]	out1,

	output logic			inexact,
	output logic			invalid
);

	logic 				sign_1;
	logic [F_EXP-1:0]		exp_1;
	logic [F_FLAC-1:0]		flac_1;
	logic				is_zero_1;
	logic				is_nan_1;
	logic				is_snan_1;
	logic				is_qnan_1;
	logic				is_inf_1;
	logic				is_num_1;
	logic				is_oor_1;
	logic				is_min_1;

	logic [F_FLAC+I_WIDTH:0]	sft_flac_1;

	logic [I_WIDTH-1:0]		rnd_flac_1;

	always_comb begin
		// parse
		sign_1     = in1[F_WIDTH-1];
		exp_1      = in1[F_WIDTH-2:F_FLAC];
		flac_1     = in1[F_FLAC-1:0];
		is_zero_1  = exp_1 == {F_EXP{1'b0}} && ~|flac_1 ? 1'b1 : 1'b0;
		is_nan_1   = exp_1 == {F_EXP{1'b1}} &&  |flac_1 ? 1'b1 : 1'b0;
		is_inf_1   = exp_1 == {F_EXP{1'b1}} && ~|flac_1 ? 1'b1 : 1'b0;
		is_snan_1  = is_nan_1 && ~flac_1[F_FLAC-1]      ? 1'b1 : 1'b0;
		is_qnan_1  = is_nan_1 &&  flac_1[F_FLAC-1]      ? 1'b1 : 1'b0;
		is_num_1   = exp_1 != {F_EXP{1'b0}} && exp_1 != {F_EXP{1'b1}} ? 1'b1 : 1'b0;

		is_oor_1   = exp_1 >= ('d127 + 'd31) ? 1'b1 : 1'b0;
		is_min_1   = exp_1 < 'd127;
	
		sft_flac_1 = {{I_WIDTH{1'b0}}, 1'b1, flac_1} << (exp_1 - 'd127);

		rnd_flac_1 = sft_flac_1[F_FLAC + I_WIDTH - 1:F_FLAC];

		out1 = is_zero_1           ? {I_WIDTH{1'b0}} :			// zero
		       is_nan_1            ? {2'h1, {I_WIDTH-2{1'b1}}} :	// NaN
		       is_inf_1 && ~sign_1 ? {2'h1, {I_WIDTH-2{1'b1}}} :	// +inf
		       is_inf_1 &&  sign_1 ? {1'b1, {I_WIDTH-1{1'b0}}} :	// -inf
		       is_min_1            ? {I_WIDTH{1'b0}} :			// num < 1.0
		       is_oor_1 && ~sign_1 ? {2'h1, {I_WIDTH-2{1'b1}}} :	// num > int_max
		       is_oor_1 &&  sign_1 ? {1'b1, {I_WIDTH-1{1'b0}}} :	// num < int_min
		       sign_1              ? ~rnd_flac_1 + 1'b1 : rnd_flac_1;

	       invalid = is_zero_1         ? 1'b0 :
		         is_nan_1          ? 1'b1 :
		         is_inf_1          ? 1'b1 :
			 is_min_1          ? 1'b0 :
			 is_oor_1          ? 1'b1 : 1'b0;

	       inexact = is_zero_1         ? 1'b0 :
		         is_nan_1          ? 1'b0 :
		         is_inf_1          ? 1'b0 :
			 is_min_1          ? 1'b1 :
			 is_oor_1          ? 1'b0 :
			 |sft_flac_1[F_FLAC-1:0] ? 1'b1 : 1'b0;
	end

endmodule

