
`include "defs.vh"

module FMUL_F
#(
	parameter	F_WIDTH = 32,
	parameter	F_EXP   = 8,
	parameter	F_FLAC  = 23
)
(
	input [F_WIDTH-1:0]		in1,
	input [F_WIDTH-1:0]		in2,
	output logic [F_WIDTH-1:0]	out,
	output logic			inexact,
	output logic			invalid
);
	logic 			sign_1, sign_2;
	logic [F_EXP-1:0]	exp_1, exp_2;
	logic [F_FLAC-1:0]	flac_1, flac_2;
	logic			is_zero_1, is_zero_2;
	logic			is_nan_1, is_nan_2;
	logic			is_inf_1, is_inf_2;

	logic				mul_sign;
	logic [F_EXP+1:0]		mul_exp;
	logic [(F_FLAC+1)*2-1:0]	mul_flac;

	logic [F_EXP+1:0]		norm_exp;
	logic [(F_FLAC+1)*2-1:0]	norm_flac;

	logic [F_EXP+1:0]		round_exp;
	logic [F_FLAC:0]		round_flac;

	logic [F_WIDTH-1:0]		mul_f;

	always_comb begin
		// parse
		sign_1    = in1[F_WIDTH-1];
		exp_1     = in1[F_WIDTH-2:F_FLAC];
		flac_1    = in1[F_FLAC-1:0];
		is_zero_1 = exp_1 == {F_EXP{1'b0}} && ~|flac_1 ? 1'b1 : 1'b0;
		is_nan_1  = exp_1 == {F_EXP{1'b1}} &&  |flac_1 ? 1'b1 : 1'b0;
		is_inf_1  = exp_1 == {F_EXP{1'b1}} && ~|flac_1 ? 1'b1 : 1'b0;
	
		sign_2    = in2[31];
		exp_2     = in2[30:23];
		flac_2    = in2[22:0];
		is_zero_2 = exp_2 == {F_EXP{1'b0}} && ~|flac_2 ? 1'b1 : 1'b0;
		is_nan_2  = exp_2 == {F_EXP{1'b1}} &&  |flac_2 ? 1'b1 : 1'b0;
		is_inf_2  = exp_2 == {F_EXP{1'b1}} && ~|flac_2 ? 1'b1 : 1'b0;
	
		// multiply
		mul_sign  = sign_1 ^ sign_2;
		mul_exp   = {1'h0, exp_1} + {1'h0, exp_2} - 10'd127;
		mul_flac  = {1'b1, flac_1} * {1'b1, flac_2};
	
		// normalize
		if(mul_flac[(F_FLAC+1)*2-1])
		begin
			norm_exp  = mul_exp + 'b1;
			norm_flac = mul_flac;
		end
		else if (~mul_flac[(F_FLAC+1)*2-1] & mul_flac[(F_FLAC+1)*2-2])
		begin
			norm_exp  = mul_exp;
			norm_flac = {mul_flac[(F_FLAC+1)*2-2:0], 1'b0};
		end else begin
			norm_exp  = mul_exp + 1'b1;
			norm_flac = mul_flac;
		end
	
		// round
		round_exp  = norm_exp;
		round_flac = norm_flac[(F_FLAC+1)*2-1:(F_FLAC+1)*2-24];
	
		// result
		mul_f = is_nan_1  || is_nan_2       ? {1'b0, {F_EXP+1{1'b1}}, {F_FLAC-1{1'b0}}} :		// NaN   * any   = NaN, any * NaN = NaN
			is_zero_1 && is_inf_2       ? {1'b0, {F_EXP+1{1'b1}}, {F_FLAC-1{1'b0}}} :			// +-0   * +-inf = NaN
			is_zero_2 && is_inf_1       ? {1'b0, {F_EXP+1{1'b1}}, {F_FLAC-1{1'b0}}} :			// +-inf * +-0   = NaN
			is_zero_1 && is_zero_2      ? {mul_sign, {F_EXP{1'b0}}, {F_FLAC{1'b0}}} :		// +-0   * +-0   = +-0
			is_inf_1  && is_inf_2       ? {mul_sign, {F_EXP{1'b1}}, {F_FLAC{1'b0}}} :		// +-inf * +-inf = +-inf
			$signed(round_exp) >= 'd255 ? {mul_sign, {F_EXP{1'b1}}, {F_FLAC{1'b0}}} :			// inf
			round_exp[9]                ? {mul_sign, {F_EXP{1'b0}}, round_flac[F_FLAC:1]} :		// subnormal number
						      {mul_sign, round_exp[F_EXP-1:0], round_flac[F_FLAC-1:0]};
	
		out = mul_f;
		invalid = is_inf_1  && is_zero_2	? 1'b0 :
		          is_inf_2  && is_zero_1	? 1'b0 :
			  is_nan_1  || is_nan_2		? 1'b1 : 1'b0;
		inexact = |norm_flac[F_FLAC:0];
	end

endmodule

