
`include "defs.vh"

function [4:0] first_1_25(input [24:0] in);
begin
	if(in[24])                      first_1_25 = 5'h00;
	else if (~in[24] && in[23])     first_1_25 = 5'h01;
	else if (~|in[24:23] && in[22]) first_1_25 = 5'h02;
	else if (~|in[24:22] && in[21]) first_1_25 = 5'h03;
	else if (~|in[24:21] && in[20]) first_1_25 = 5'h04;
	else if (~|in[24:20] && in[19]) first_1_25 = 5'h05;
	else if (~|in[24:19] && in[18]) first_1_25 = 5'h06;
	else if (~|in[24:18] && in[17]) first_1_25 = 5'h07;
	else if (~|in[24:17] && in[16]) first_1_25 = 5'h08;
	else if (~|in[24:16] && in[15]) first_1_25 = 5'h09;
	else if (~|in[24:15] && in[14]) first_1_25 = 5'h0a;
	else if (~|in[24:14] && in[13]) first_1_25 = 5'h0b;
	else if (~|in[24:13] && in[12]) first_1_25 = 5'h0c;
	else if (~|in[24:12] && in[11]) first_1_25 = 5'h0d;
	else if (~|in[24:11] && in[10]) first_1_25 = 5'h0e;
	else if (~|in[24:10] && in[ 9]) first_1_25 = 5'h0f;
	else if (~|in[24: 9] && in[ 8]) first_1_25 = 5'h10;
	else if (~|in[24: 8] && in[ 7]) first_1_25 = 5'h11;
	else if (~|in[24: 7] && in[ 6]) first_1_25 = 5'h12;
	else if (~|in[24: 6] && in[ 5]) first_1_25 = 5'h13;
	else if (~|in[24: 5] && in[ 4]) first_1_25 = 5'h14;
	else if (~|in[24: 4] && in[ 3]) first_1_25 = 5'h15;
	else if (~|in[24: 3] && in[ 2]) first_1_25 = 5'h16;
	else if (~|in[24: 2] && in[ 1]) first_1_25 = 5'h17;
	else if (~|in[24: 1] && in[ 0]) first_1_25 = 5'h18;
	else                            first_1_25 = 5'h1f;
end
endfunction

function last_n_dirty_23(input [22:0] in, input [7:0] mag_shift);
begin
	logic [22:0]	mask;
	mask = ('b1 << mag_shift) - 'b1;
	last_n_dirty_23 = |(in & mask);
end
endfunction

module FADD_F
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
	logic			is_num_1, is_num_2;

	logic 			mm_swap;
	logic			mm_is_zero_1, mm_is_zero_2;
	logic			mm_sign_1, mm_sign_2;
	logic [F_EXP-1:0]	mm_exp_1,  mm_exp_2;
	logic [F_FLAC-1:0]	mm_flac_1, mm_flac_2;

	logic [F_EXP-1:0]	mag_shift;
	logic			sf_sign_1, sf_sign_2;
	logic [F_EXP-1:0]	sf_exp_1, sf_exp_2;
	logic [F_FLAC:0]	sf_flac_1, sf_flac_2;

	logic [F_EXP-1:0]	cm_exp_1,  cm_exp_2;
	logic [F_FLAC+1:0]	cm_flac_1, cm_flac_2;

	logic [F_EXP-1:0]	add_exp;
	logic [F_FLAC+2:0]	add_flac;

	logic			abs_sign;
	logic [F_EXP-1:0]	abs_exp;
	logic [F_FLAC+1:0]	abs_flac;

	logic [4:0]		norm_shift;
	logic			norm_is_zero;
	logic			norm_sign;
	logic [F_EXP-1:0]	norm_exp;
	logic [F_FLAC+1:0]	norm_flac;

	logic			round_sign;
	logic [F_EXP-1:0]	round_exp;
	logic [F_FLAC-1:0]	round_flac;

	logic [F_WIDTH-1:0]	add_f;

	always_comb begin
		// parse
		sign_1    = in1[F_WIDTH-1];
		exp_1     = in1[F_WIDTH-2:F_FLAC];
		flac_1    = in1[F_FLAC-1:0];
		is_zero_1 = exp_1 == {F_EXP{1'b0}} && ~|flac_1 ? 1'b1 : 1'b0;
		is_nan_1  = exp_1 == {F_EXP{1'b1}} &&  |flac_1 ? 1'b1 : 1'b0;
		is_inf_1  = exp_1 == {F_EXP{1'b1}} && ~|flac_1 ? 1'b1 : 1'b0;
		is_num_1  = exp_1 != {F_EXP{1'b0}} && exp_1 != {F_EXP{1'b1}} ? 1'b1 : 1'b0;

		sign_2    = in2[F_WIDTH-1];
		exp_2     = in2[F_WIDTH-2:F_FLAC];
		flac_2    = in2[F_FLAC-1:0];
		is_zero_2 = exp_2 == {F_EXP{1'b0}} && ~|flac_2 ? 1'b1 : 1'b0;
		is_nan_2  = exp_2 == {F_EXP{1'b1}} &&  |flac_2 ? 1'b1 : 1'b0;
		is_inf_2  = exp_2 == {F_EXP{1'b1}} && ~|flac_2 ? 1'b1 : 1'b0;
		is_num_2  = exp_2 != {F_EXP{1'b0}} && exp_2 != {F_EXP{1'b1}} ? 1'b1 : 1'b0;

		// ensure mm_1 > mm_2
		mm_swap   = exp_1 < exp_2 ? 1'b1 : 1'b0;
		mm_is_zero_1 = mm_swap ? is_zero_2 : is_zero_1;
		mm_sign_1 = mm_swap ? sign_2 : sign_1;
		mm_exp_1  = mm_swap ? exp_2  : exp_1;
		mm_flac_1 = mm_swap ? flac_2 : flac_1;

		mm_is_zero_2 = mm_swap ? is_zero_1 : is_zero_2;
		mm_sign_2 = mm_swap ? sign_1 : sign_2;
		mm_exp_2  = mm_swap ? exp_1  : exp_2;
		mm_flac_2 = mm_swap ? flac_1 : flac_2;

		// shift
		mag_shift = mm_exp_1 - mm_exp_2;
		sf_sign_1 = mm_sign_1;
		sf_exp_1  = mm_is_zero_1 ? mm_exp_2 : mm_exp_1;
		sf_flac_1 = mm_is_zero_1 ? 'h0 : {1'b1, mm_flac_1};

		sf_sign_2 = mm_sign_2;
		sf_exp_2  = mm_is_zero_2 ? mm_exp_1 : mm_exp_2;
		sf_flac_2 = mm_is_zero_2 ? 'h0 : ({1'b1, mm_flac_2} >> mag_shift);

		// two's comp
		cm_exp_1  = sf_exp_1;
		cm_flac_1 = sf_sign_1 ? ~{1'b0, sf_flac_1} + 'b1 : {1'b0, sf_flac_1};

		cm_exp_2  = sf_exp_2;
		cm_flac_2 = sf_sign_2 ? ~{1'b0, sf_flac_2} + 'b1 : {1'b0, sf_flac_2};
	
		// add
		add_exp   = cm_exp_1;
		add_flac  = {cm_flac_1[F_FLAC+1], cm_flac_1} + {cm_flac_2[24], cm_flac_2};

		// abs
		abs_sign   = add_flac[F_FLAC+2];
		abs_exp    = add_exp;
		abs_flac   = abs_sign ? ~add_flac[F_FLAC+1:0] + 'b1 : add_flac[F_FLAC+1:0];

		// normalize
		norm_shift = first_1_25(abs_flac);
		norm_is_zero = norm_shift == 5'h1f ? 1'b1 : 1'b0;
		norm_sign  = abs_sign;
		norm_exp   = abs_exp - {3'h0, norm_shift} + 'h1;
		norm_flac  = abs_flac << norm_shift;

		// round
		round_sign = norm_sign;
		round_exp  = norm_exp;
		round_flac = norm_flac[F_FLAC:1];

		// result
		add_f = {round_sign, round_exp, round_flac};
	
		out = is_inf_1  && is_inf_2 && (sign_1 ^ sign_2) ? {1'b0, {F_EXP+1{1'b1}}, {F_FLAC-1{1'b0}}} :	// inf-inf or -inf+inf = qNaN

		      is_nan_1  || is_nan_2  ? {1'b0, {F_EXP+1{1'b1}}, {F_FLAC-1{1'b0}}} :	// NaN + any = NaN, any + NaN = NaN
		      is_inf_1               ? in1 :						// +-inf + (any) = +-inf
		      is_inf_2               ? in2 :						// (any) + +-inf = +-inf
		      is_zero_1 && is_zero_2 ? {F_WIDTH{1'b0}} :				// +-0   + +-0   = +0
		      is_zero_1 && is_num_2  ? in2 :						// +-0   + num	 = num
		      is_zero_2 && is_num_1  ? in1 :						// num   + +-0   = num
		      norm_is_zero           ? {F_WIDTH{1'b0}} :				// flac is zero
						add_f;
		inexact = norm_flac[0] | (mag_shift > 0 ? last_n_dirty_23(mm_flac_2, mag_shift) : 1'b0);
		invalid = is_inf_1  && is_inf_2 && (sign_1 ^ sign_2) ||
			  is_nan_1  || is_nan_2 ? 1'b1 : 1'b0;
	end

endmodule

