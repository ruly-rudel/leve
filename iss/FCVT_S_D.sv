
`ifndef _fcvt_s_d_sv_
`define _fcvt_s_d_sv_

`include "defs.vh"
`include "FLOAT.sv"

class FCVT_S_D
#(
	parameter type	T = double_t,
	parameter type	S = float_t,
	parameter	F_WIDTH = 32,
	parameter	F_EXP   = 8,
	parameter	F_FLAC  = 23,
	parameter	D_WIDTH = 64,
	parameter	D_EXP   = 11,
	parameter	D_FLAC  = 52
);
	bit 			sign_f;
	bit [F_EXP-1:0]		exp_f;
	bit [F_FLAC-1:0]	flac_f;
	bit			is_zero_f;
	bit			is_nan_f;
	bit			is_inf_f;
	bit			is_qnan_f;
	bit			is_snan_f;
	bit			is_num_f;
	bit			is_sub_f;

	bit 			sign_d;
	bit [D_EXP-1:0]		exp_d;
	bit [D_FLAC-1:0]	flac_d;
	bit			is_zero_d;
	bit			is_nan_d;
	bit			is_inf_d;
	bit			is_qnan_d;
	bit			is_snan_d;
	bit			is_num_d;
	bit			is_sub_d;

	function void parse_float
	(
		input [F_WIDTH-1:0]		in1
	);
		sign_f    = in1[F_WIDTH-1];
		exp_f     = in1[F_WIDTH-2:F_FLAC];
		flac_f    = in1[F_FLAC-1:0];
		is_zero_f = exp_f == {F_EXP{1'b0}} && ~|flac_f ? 1'b1 : 1'b0;
		is_nan_f  = exp_f == {F_EXP{1'b1}} &&  |flac_f ? 1'b1 : 1'b0;
		is_inf_f  = exp_f == {F_EXP{1'b1}} && ~|flac_f ? 1'b1 : 1'b0;
		is_snan_f = is_nan_f && ~flac_f[F_FLAC-1]      ? 1'b1 : 1'b0;
		is_qnan_f = is_nan_f &&  flac_f[F_FLAC-1]      ? 1'b1 : 1'b0;
		is_num_f  = exp_f != {F_EXP{1'b0}} && exp_f != {F_EXP{1'b1}} ? 1'b1 : 1'b0;
		is_sub_f  = exp_f == {F_EXP{1'b0}} &&  |flac_f ? 1'b1 : 1'b0;
	endfunction

	function void parse_double
	(
		input [D_WIDTH-1:0]		in1
	);
		sign_d    = in1[D_WIDTH-1];
		exp_d     = in1[D_WIDTH-2:D_FLAC];
		flac_d    = in1[D_FLAC-1:0];
		is_zero_d = exp_d == {D_EXP{1'b0}} && ~|flac_d ? 1'b1 : 1'b0;
		is_nan_d  = exp_d == {D_EXP{1'b1}} &&  |flac_d ? 1'b1 : 1'b0;
		is_inf_d  = exp_d == {D_EXP{1'b1}} && ~|flac_d ? 1'b1 : 1'b0;
		is_snan_d = is_nan_d && ~flac_d[D_FLAC-1]      ? 1'b1 : 1'b0;
		is_qnan_d = is_nan_d &&  flac_d[D_FLAC-1]      ? 1'b1 : 1'b0;
		is_num_d  = exp_d != {D_EXP{1'b0}} && exp_d != {D_EXP{1'b1}} ? 1'b1 : 1'b0;
		is_sub_d  = exp_d == {D_EXP{1'b0}} &&  |flac_d ? 1'b1 : 1'b0;
	endfunction

	task double_from_float
	(
		input  [F_WIDTH-1:0]		in1,
		output T			out
	);
		// parse
		parse_float(in1);

		sign_d = sign_f;
		exp_d  = {3'h0, exp_f} - ((1<<(F_EXP-1)) - 1) + ((1<<(D_EXP-1)) - 1);
		flac_d = {flac_f, {D_FLAC-F_FLAC{1'b0}}};

		out.val = 
			is_zero_f ? {sign_d, {D_EXP{1'b0}},   {D_FLAC{1'b0}}} :		// +-0
			is_nan_f  ? {1'b0,   {D_EXP+1{1'b1}}, {D_FLAC-1{1'b0}}} :	// NaN
			is_inf_f  ? {sign_d, {D_EXP{1'b1}},   {D_FLAC{1'b0}}} :		// +-inf
				    {sign_d, exp_d, flac_d};

		out.inexact = 1'b0;
		out.invalid = is_snan_f ? 1'b1 : 1'b0;
	endtask

	task float_from_double
	(
		input  [D_WIDTH-1:0]		in1,
		output S			out
	);
		bit [D_EXP:0]		exp;
		// parse
		parse_double(in1);

		sign_f = sign_d;
		exp    = exp_d + ((1<<(F_EXP-1)) - 1) - ((1<<(D_EXP-1)) - 1);
		exp_f  = exp[7:0];
		is_inf_f = $signed(exp) < 0              ? 1'b1 :
		           $signed(exp) > ((1<<F_EXP)-1) ? 1'b1 : 1'b0;
		flac_f = flac_d[D_FLAC-1:D_FLAC-F_FLAC];

		out.val = 
			is_zero_d ? {sign_f, {F_EXP{1'b0}},   {F_FLAC{1'b0}}} :		// +-0
			is_nan_d  ? {1'b0,   {F_EXP+1{1'b1}}, {F_FLAC-1{1'b0}}} :	// NaN
			is_inf_d  ? {sign_f, {F_EXP{1'b1}},   {F_FLAC{1'b0}}} :		// +-inf
			is_inf_f  ? {sign_f, {F_EXP{1'b1}},   {F_FLAC{1'b0}}} :		// +-inf
				    {sign_f, exp_f, flac_f};

		out.inexact = |flac_d[D_FLAC-F_FLAC-1:0] | is_inf_f;
		out.invalid = is_snan_d ? 1'b1 : 1'b0;
	endtask

endclass : FCVT_S_D;

`endif	// _fcvt_s_d_sv_
