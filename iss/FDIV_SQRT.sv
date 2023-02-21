`ifndef _fdiv_sqrt_sv_
`define _fdiv_sqrt_sv_

`include "FLOAT.sv"

typedef struct packed {
	bit [35:0]	val;
	bit		inexact;
	bit		invalid;
} float_d_t;

typedef struct packed {
	bit [67:0]	val;
	bit		inexact;
	bit		invalid;
} double_d_t;

class FDIV_SQRT
#(
	parameter type	T = float_d_t,
	parameter	F_WIDTH = 36,
	parameter	F_EXP   = 8,
	parameter	F_FLAC  = 27
);
	FLOAT
	#(
		.T		(T),
		.F_WIDTH	(F_WIDTH),
		.F_EXP		(F_EXP),
		.F_FLAC		(F_FLAC)
	) float = new;

	bit 			sign_1, sign_2;
	bit [F_EXP-1:0]		exp_1, exp_2;
	bit [F_FLAC-1:0]	flac_1, flac_2;
	bit			is_zero_1, is_zero_2;
	bit			is_nan_1, is_nan_2;
	bit			is_inf_1, is_inf_2;
	bit			is_qnan_1, is_qnan_2;
	bit			is_snan_1, is_snan_2;
	bit			is_num_1, is_num_2;
	bit			is_sub_1, is_sub_2;
	
	function void parse
	(
		input [F_WIDTH-1:0]		in1,
		input [F_WIDTH-1:0]		in2
	);
		sign_1    = in1[F_WIDTH-1];
		exp_1     = in1[F_WIDTH-2:F_FLAC];
		flac_1    = in1[F_FLAC-1:0];
		is_zero_1 = exp_1 == {F_EXP{1'b0}} && ~|flac_1 ? 1'b1 : 1'b0;
		is_nan_1  = exp_1 == {F_EXP{1'b1}} &&  |flac_1 ? 1'b1 : 1'b0;
		is_inf_1  = exp_1 == {F_EXP{1'b1}} && ~|flac_1 ? 1'b1 : 1'b0;
		is_snan_1 = is_nan_1 && ~flac_1[F_FLAC-1]      ? 1'b1 : 1'b0;
		is_qnan_1 = is_nan_1 &&  flac_1[F_FLAC-1]      ? 1'b1 : 1'b0;
		is_num_1  = exp_1 != {F_EXP{1'b0}} && exp_1 != {F_EXP{1'b1}} ? 1'b1 : 1'b0;
		is_sub_1  = exp_1 == {F_EXP{1'b0}} &&  |flac_1 ? 1'b1 : 1'b0;

		sign_2    = in2[F_WIDTH-1];
		exp_2     = in2[F_WIDTH-2:F_FLAC];
		flac_2    = in2[F_FLAC-1:0];
		is_zero_2 = exp_2 == {F_EXP{1'b0}} && ~|flac_2 ? 1'b1 : 1'b0;
		is_nan_2  = exp_2 == {F_EXP{1'b1}} &&  |flac_2 ? 1'b1 : 1'b0;
		is_inf_2  = exp_2 == {F_EXP{1'b1}} && ~|flac_2 ? 1'b1 : 1'b0;
		is_snan_2 = is_nan_2 && ~flac_2[F_FLAC-1]      ? 1'b1 : 1'b0;
		is_qnan_2 = is_nan_2 &&  flac_2[F_FLAC-1]      ? 1'b1 : 1'b0;
		is_num_2  = exp_2 != {F_EXP{1'b0}} && exp_2 != {F_EXP{1'b1}} ? 1'b1 : 1'b0;
		is_sub_2  = exp_2 == {F_EXP{1'b0}} &&  |flac_2 ? 1'b1 : 1'b0;
	endfunction

	task fdiv
	(
		input [F_WIDTH-1:0]		in1,
		input [F_WIDTH-1:0]		in2,
		output T			out
	);
		bit [F_EXP:0]		unbias_exp;
		bit [F_EXP:0]		inv_exp;
		bit [F_EXP:0]		bias_inv_exp;
		bit [F_WIDTH-1:0]	xn;
		bit [F_WIDTH-1:0]	xn_times_2;
		bit [F_EXP-1:0]		xn_times_2_exp;
		T			xn_dbl;
		T			xn_dbl_in2;
		T			xnp1;
		T			div_o;

		// parse
		parse(in1, in2);
		$display("[INFO] div in1 = %1b.%2h.%6h", sign_1, exp_1, flac_1);
		$display("[INFO] div in2 = %1b.%2h.%6h", sign_2, exp_2, flac_2);

		// newton's method
		// 1. initial value
		unbias_exp   = {1'h0, exp_2} - ((1 << (F_EXP -1)) - 1);
		inv_exp      = ~unbias_exp + 'b1;
		bias_inv_exp = inv_exp + ((1 << (F_EXP -1)) - 1);
		xn           = {sign_2, bias_inv_exp[F_EXP-1:0], {F_FLAC{1'b0}}};

		// 2. iteration
		for(int i = 0; i < 7; i = i + 1) begin
			$display("[INFO] div xn = %1b.%2h.%6h", xn[F_WIDTH-1], xn[F_WIDTH-2:F_FLAC], xn[F_FLAC-1:0]);
			xn_times_2_exp = xn[F_WIDTH-2:F_FLAC] + 'b1;
			xn_times_2 = {xn[F_WIDTH-1], xn_times_2_exp, xn[F_FLAC-1:0]};
			float.fmul(xn, xn, xn_dbl);
			float.fmul(xn_dbl.val, in2, xn_dbl_in2);
			float.fsub(xn_times_2, xn_dbl_in2.val, xnp1);

			xn = xnp1.val;
		end

		// mul in1 * 1/in2
		float.fmul(in1, xnp1.val, div_o);

		// result
		out.val =
			is_nan_1  || is_nan_2    ? {1'b0, {F_EXP+1{1'b1}}, {F_FLAC-1{1'b0}}} :		// NaN   / any   = NaN, any / NaN = NaN
			is_zero_2                ? {1'b0, {F_EXP+1{1'b1}}, {F_FLAC-1{1'b0}}} :		// any / 0 = NaN
			is_inf_1  && is_inf_2    ? {1'b0, {F_EXP+1{1'b1}}, {F_FLAC-1{1'b0}}} :		// inf / inf = NaN
			is_zero_1                ? {sign_1 ^ sign_2, {F_EXP{1'b0}}, {F_FLAC{1'b0}}} :	// zero / any = zero
			is_inf_1  && is_num_2    ? {sign_1 ^ sign_2, {F_EXP{1'b1}}, {F_FLAC{1'b0}}} :	// inf / num = inf
			is_num_1  && is_inf_2    ? {sign_1 ^ sign_2, {F_EXP{1'b0}}, {F_FLAC{1'b0}}} :	// num / inf = zero
						   div_o.val;

		out.invalid = is_zero_2			? 1'b1 :
		              is_inf_1  && is_inf_1	? 1'b1 :
			      is_nan_1  || is_nan_2	? 1'b1 : div_o.invalid;
		out.inexact = div_o.inexact;
	endtask

endclass : FDIV_SQRT

`endif	// _fdiv_sqrt_sv_
