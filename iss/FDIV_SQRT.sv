`ifndef _fdiv_sqrt_sv_
`define _fdiv_sqrt_sv_

`include "FLOAT.sv"

`define FDIV_EXTRA 	4
//`define USE_MAGIC_AT_FSQRT

typedef struct packed {
	bit [31+`FDIV_EXTRA:0]	val;
	bit		inexact;
	bit		invalid;
} float_d_t;

typedef struct packed {
	bit [63+`FDIV_EXTRA:0]	val;
	bit		inexact;
	bit		invalid;
} double_d_t;

class FDIV_SQRT
#(
	parameter type	T = float_t,
	parameter type	S = float_d_t,
	parameter	F_WIDTH = 32,
	parameter	F_EXP   = 8,
	parameter	F_FLAC  = 23,
	parameter	EXTRA	= `FDIV_EXTRA,
	parameter	MAGIC	= 32'h5f3759df
);
	FLOAT
	#(
		.T		(S),
		.F_WIDTH	(F_WIDTH + EXTRA),
		.F_EXP		(F_EXP),
		.F_FLAC		(F_FLAC + EXTRA)
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
		bit [F_WIDTH-1+EXTRA:0]	xn;
		bit [F_WIDTH-1+EXTRA:0]	xn_times_2;
		bit [F_EXP-1:0]		xn_times_2_exp;
		S			xn_dbl;
		S			xn_dbl_in2;
		S			xnp1;
		S			div_o;

		// parse
		parse(in1, in2);
		$display("[INFO] div in1 = %1b.%2h.%6h", sign_1, exp_1, flac_1);
		$display("[INFO] div in2 = %1b.%2h.%6h", sign_2, exp_2, flac_2);

		// newton's method
		// 1. initial value
		unbias_exp   = {1'h0, exp_2} - ((1 << (F_EXP -1)) - 1);
		inv_exp      = ~unbias_exp + 'b1;
		bias_inv_exp = inv_exp + ((1 << (F_EXP -1)) - 1);
		xn           = {sign_2, bias_inv_exp[F_EXP-1:0], {F_FLAC+EXTRA{1'b0}}};

		// 2. iteration
		for(int i = 0; i < 7; i = i + 1) begin
			$display("[INFO] div xn = %1b.%2h.%6h", xn[F_WIDTH-1+EXTRA], xn[F_WIDTH-2+EXTRA:F_FLAC+EXTRA], xn[F_FLAC-1+EXTRA:0]);
			xn_times_2_exp = xn[F_WIDTH-2+EXTRA:F_FLAC+EXTRA] + 'b1;
			xn_times_2 = {xn[F_WIDTH-1+EXTRA], xn_times_2_exp, xn[F_FLAC-1+EXTRA:0]};
			float.fmul(xn, xn, xn_dbl);
			float.fmul(xn_dbl.val, {in2, {EXTRA{1'b0}}}, xn_dbl_in2);
			float.fsub(xn_times_2, xn_dbl_in2.val, xnp1);

			xn = xnp1.val;
		end

		// mul in1 * 1/in2
		float.fmul({in1, {EXTRA{1'b0}}}, xnp1.val, div_o);

		// result
		out.val =
			is_nan_1  || is_nan_2    ? {1'b0, {F_EXP+1{1'b1}}, {F_FLAC-1{1'b0}}} :		// NaN   / any   = NaN, any / NaN = NaN
			is_zero_2                ? {1'b0, {F_EXP+1{1'b1}}, {F_FLAC-1{1'b0}}} :		// any / 0 = NaN
			is_inf_1  && is_inf_2    ? {1'b0, {F_EXP+1{1'b1}}, {F_FLAC-1{1'b0}}} :		// inf / inf = NaN
			is_zero_1                ? {sign_1 ^ sign_2, {F_EXP{1'b0}}, {F_FLAC{1'b0}}} :	// zero / any = zero
			is_inf_1  && is_num_2    ? {sign_1 ^ sign_2, {F_EXP{1'b1}}, {F_FLAC{1'b0}}} :	// inf / num = inf
			is_num_1  && is_inf_2    ? {sign_1 ^ sign_2, {F_EXP{1'b0}}, {F_FLAC{1'b0}}} :	// num / inf = zero
						   div_o.val[F_WIDTH+EXTRA-1:EXTRA] + {{F_WIDTH-1{1'b0}}, div_o.val[EXTRA-1]};

		out.invalid = is_zero_2			? 1'b1 :
		              is_inf_1  && is_inf_1	? 1'b1 :
			      is_nan_1  || is_nan_2	? 1'b1 : div_o.invalid;
		out.inexact = div_o.inexact;
	endtask

	task fsqrt
	(
		input [F_WIDTH-1:0]		in1,
		output T			out
	);
		bit [F_WIDTH-1:0]	x0;
		bit [F_EXP:0]		unbias_exp;
		bit [F_EXP:0]		half_exp;
		bit [F_EXP:0]		inv_half_exp;
		bit [F_EXP:0]		bias_inv_half_exp;
		bit [F_WIDTH-1+EXTRA:0]	xn;
		bit [F_WIDTH-1+EXTRA:0]	xn_half;
		bit [F_EXP-1:0]		xn_half_exp;
		bit [F_WIDTH-1+EXTRA:0]	in1_half;
		bit [F_EXP-1:0]		in1_half_exp;
		S			xn_dbl;
		S			xn_dbl_in1;
		bit [F_WIDTH-1+EXTRA:0]	three;
		bit [F_WIDTH-1+EXTRA:0]	three_half;
		S			three_minus_xn_dbl_in1;
		S			xnp1;
		S			sqrt_o;
		S			double_sqrt_o;

		// parse
		parse(in1, in1);
		//$display("[INFO] sqrt in1 = %1b.%2h.%6h", sign_1, exp_1, flac_1);

		// newton's method
		// 1. initial value
`ifdef USE_MAGIC_AT_FSQRT
		x0            = MAGIC - {1'b0, in1[F_WIDTH-1:1]};
		xn            = {x0, {EXTRA{1'b0}}};
`else
		unbias_exp    = {1'h0, exp_1} - ((1 << (F_EXP -1)) - 1);
		half_exp      = $signed(unbias_exp) >>> 1;
		inv_half_exp  = ~half_exp + 'b1;
		bias_inv_half_exp = inv_half_exp + ((1 << (F_EXP -1)) - 1) - 'b1;
		xn            = {sign_1, bias_inv_half_exp[F_EXP-1:0], {F_FLAC+EXTRA{1'b0}}};
`endif
		// 2. iteration
		for(int i = 0; i < 8; i = i + 1) begin
			//$display("[INFO] sqrt xn = %1b.%2h.%6h", xn[F_WIDTH-1+EXTRA], xn[F_WIDTH-2+EXTRA:F_FLAC+EXTRA], xn[F_FLAC-1+EXTRA:0]);
			/*
			xn_half_exp = xn[F_WIDTH-2+EXTRA:F_FLAC+EXTRA] - 'b1;
			xn_half = {xn[F_WIDTH-1+EXTRA], xn_half_exp, xn[F_FLAC-1+EXTRA:0]};
			float.fmul(xn, xn, xn_dbl);
			float.fmul(xn_dbl.val, {in1, {EXTRA{1'b0}}}, xn_dbl_in1);
			three = {1'b0, {1'b1, {F_EXP-1{1'b0}}}, {1'b1, {F_FLAC-1+EXTRA{1'b0}}}};
			float.fsub(three, xn_dbl_in1.val, three_minus_xn_dbl_in1);
			float.fmul(xn_half, three_minus_xn_dbl_in1.val, xnp1);
			*/

			in1_half_exp = exp_1 - 'b1;
			in1_half = {sign_1, in1_half_exp, flac_1, {EXTRA{1'b0}}};
			float.fmul(xn, xn, xn_dbl);
			float.fmul(xn_dbl.val, in1_half, xn_dbl_in1);
			three_half = {1'b0, {1'b0, {F_EXP-1{1'b1}}}, {1'b1, {F_FLAC-1+EXTRA{1'b0}}}};
			float.fsub(three_half, xn_dbl_in1.val, three_minus_xn_dbl_in1);
			float.fmul(xn, three_minus_xn_dbl_in1.val, xnp1);

			xn = xnp1.val;
		end

		// mul in1 * in1^(-1/2) = in1^(1/2)
		float.fmul({in1, {EXTRA{1'b0}}}, xnp1.val, sqrt_o);

		// kenzan
		float.fmul(sqrt_o.val, sqrt_o.val, double_sqrt_o);

		// result
		out.val = is_nan_1  ? {1'b0, {F_EXP+1{1'b1}}, {F_FLAC-1{1'b0}}} :		// Nan  -> Nan
			  is_zero_1 ? {sign_1, {F_EXP{1'b0}}, {F_FLAC{1'b0}}} :			// zero -> zero
			  is_inf_1  ? {sign_1, {F_EXP{1'b1}}, {F_FLAC{1'b0}}} :			// inf  -> inf
			  is_num_1 && sign_1 ? {1'b0, {F_EXP+1{1'b1}}, {F_FLAC-1{1'b0}}} :	// -num -> NaN
						   sqrt_o.val[F_WIDTH-1+EXTRA:EXTRA] + {{F_WIDTH-1{1'b0}}, sqrt_o.val[EXTRA-1]};

		out.invalid = is_nan_1 || is_num_1 && sign_1 ? 1'b1 : sqrt_o.invalid;
		out.inexact = is_nan_1 || is_num_1 && sign_1 ? 1'b0 :
			double_sqrt_o.val[F_WIDTH-1+EXTRA:EXTRA] == in1 ? double_sqrt_o.inexact : 1'b1;
		//$display("[INFO] sqrt^2  = %1b.%2h.%6h", double_sqrt_o.val[F_WIDTH-1+EXTRA], double_sqrt_o.val[F_WIDTH-1+EXTRA-1:F_FLAC+EXTRA], double_sqrt_o.val[F_FLAC+EXTRA-1:EXTRA]);
	endtask

endclass : FDIV_SQRT

`endif	// _fdiv_sqrt_sv_
