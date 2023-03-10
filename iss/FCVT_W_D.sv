
`ifndef _fcvt_w_d_sv_
`define _fcvt_w_d_sv_

`include "defs.vh"
`include "FLOAT.sv"

class FCVT_W_D
#(
	parameter type	T = double_t,
	parameter type	S = word_t,
	parameter	F_WIDTH = 64,
	parameter	F_EXP   = 11,
	parameter	F_FLAC  = 52,
	parameter	I_WIDTH = 32
);
	bit 			sign_1;
	bit [F_EXP-1:0]		exp_1;
	bit [F_FLAC-1:0]	flac_1;
	bit			is_zero_1;
	bit			is_nan_1;
	bit			is_inf_1;
	bit			is_qnan_1;
	bit			is_snan_1;
	bit			is_num_1;
	bit			is_sub_1;

	function void parse_float
	(
		input [F_WIDTH-1:0]		in1
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
	endfunction

	function void parse_word
	(
		input [I_WIDTH/2-1:0]		in1
	);
		sign_1     = in1[I_WIDTH/2-1];
		is_zero_1  = ~|in1;
	endfunction

	function void parse_long
	(
		input [I_WIDTH-1:0]		in1
	);
		sign_1     = in1[I_WIDTH-1];
		is_zero_1  = ~|in1;
	endfunction

	function [F_EXP-1:0] first_1(input [I_WIDTH-1:0] in);
		for(integer i = 0; i < I_WIDTH - 1; i = i + 1) begin
			if(|(1 << (I_WIDTH - 1 - i) & in)) begin
				return i[F_EXP-1:0];
			end
		end
		return {F_EXP{1'b1}};
	endfunction

	task real_from_int
	(
		input [I_WIDTH-1:0]		in1,
		output T			out
	);
		bit [I_WIDTH-1:0]		abs_1;
	
		bit [F_EXP-1:0]			sft_amt_1;
		bit [I_WIDTH-1:0]		sft_flac_1;
	
		bit [F_FLAC-1:0]		rnd_flac_1;
	
		bit [F_EXP-1:0]			exp_1;
		bit [F_FLAC-1:0]		flac_1;

		// parse
		parse_long(in1);

		// abs
		abs_1      = sign_1 ? ~in1 + 1'b1 : in1;

		// shift
		sft_amt_1  = first_1(abs_1);
		sft_flac_1 = abs_1 << sft_amt_1;

		// round
		rnd_flac_1 = {sft_flac_1[I_WIDTH-2:0], {F_FLAC-I_WIDTH+1{1'b0}}};

		exp_1      = (1 << (F_EXP - 1)) - 1 + I_WIDTH - 1 - sft_amt_1;
		flac_1     = rnd_flac_1;

		out.val = is_zero_1 ? {F_WIDTH{1'b0}} : {sign_1, exp_1, flac_1};

		out.inexact = 1'b0;
		out.invalid = 1'b0;
	endtask

	task real_from_uint
	(
		input [I_WIDTH-1:0]		in1,
		output T			out
	);
		bit [F_EXP-1:0]			sft_amt_1;
		bit [I_WIDTH-1:0]		sft_flac_1;
	
		bit [F_FLAC-1:0]		rnd_flac_1;
	
		bit [F_EXP-1:0]			exp_1;
		bit [F_FLAC-1:0]		flac_1;

		// parse
		parse_long(in1);

		// shift
		sft_amt_1  = first_1(in1);
		sft_flac_1 = in1 << sft_amt_1;

		// round
		rnd_flac_1 = {sft_flac_1[I_WIDTH-2:0], {F_FLAC-I_WIDTH+1{1'b0}}};

		exp_1      = (1 << (F_EXP - 1)) - 1 + I_WIDTH - 1 - sft_amt_1;
		flac_1     = rnd_flac_1;

		out.val = is_zero_1 ? {F_WIDTH{1'b0}} : {1'b0, exp_1, flac_1};

		out.inexact = 1'b0;
		out.invalid = 1'b0;
	endtask

	task int_from_real
	(
		input [F_WIDTH-1:0]		in1,
		output S			out
	);
	
		bit				is_oor_1;
		bit				is_min_1;
	
		bit [F_FLAC+I_WIDTH:0]		sft_flac_1;
	
		bit [I_WIDTH-1:0]		rnd_flac_1;

		// parse
		parse_float(in1);
		is_oor_1   = exp_1 >= ((1 << (F_EXP - 1)) - 1 + I_WIDTH - 1) ? 1'b1 : 1'b0;
		is_min_1   = exp_1 < ((1 << (F_EXP - 1)) - 1);
	
		sft_flac_1 = {{I_WIDTH{1'b0}}, 1'b1, flac_1} << (exp_1 - ((1<<(F_EXP-1))-1));

		rnd_flac_1 = sft_flac_1[F_FLAC + I_WIDTH - 1:F_FLAC];

		out.val =
		       is_zero_1           ? {I_WIDTH{1'b0}} :			// zero
		       is_nan_1            ? {2'h1, {I_WIDTH-2{1'b1}}} :	// NaN
		       is_inf_1 && ~sign_1 ? {2'h1, {I_WIDTH-2{1'b1}}} :	// +inf
		       is_inf_1 &&  sign_1 ? {1'b1, {I_WIDTH-1{1'b0}}} :	// -inf
		       is_min_1            ? {I_WIDTH{1'b0}} :			// num < 1.0
		       is_oor_1 && ~sign_1 ? {2'h1, {I_WIDTH-2{1'b1}}} :	// num > int_max
		       is_oor_1 &&  sign_1 ? {1'b1, {I_WIDTH-1{1'b0}}} :	// num < int_min
		       sign_1              ? ~rnd_flac_1 + 1'b1 : rnd_flac_1;

		out.invalid =
		         is_zero_1         ? 1'b0 :
		         is_nan_1          ? 1'b1 :
		         is_inf_1          ? 1'b1 :
			 is_min_1          ? 1'b0 :
			 is_oor_1          ? 1'b1 : 1'b0;

		out.inexact =
		         is_zero_1         ? 1'b0 :
		         is_nan_1          ? 1'b0 :
		         is_inf_1          ? 1'b0 :
			 is_min_1          ? 1'b1 :
			 is_oor_1          ? 1'b0 :
			 |sft_flac_1[F_FLAC-1:0] ? 1'b1 : 1'b0;
	
	endtask


	task uint_from_real
	(
		input [F_WIDTH-1:0]		in1,
		output S			out
	);
		bit				is_oor_1;
		bit				is_min_1;
	
		bit [F_FLAC+I_WIDTH:0]		sft_flac_1;
	
		bit [I_WIDTH-1:0]		rnd_flac_1;

		// parse
		parse_float(in1);
		is_oor_1   = exp_1 >= ((1 << (F_EXP - 1)) - 1 + I_WIDTH) ? 1'b1 : 1'b0;
		is_min_1   = exp_1 < ((1 << (F_EXP - 1)) - 1);
	
		sft_flac_1 = {{I_WIDTH{1'b0}}, 1'b1, flac_1} << (exp_1 - ((1<<(F_EXP-1))-1));

		rnd_flac_1 = sft_flac_1[F_FLAC + I_WIDTH - 1:F_FLAC];

		out.val =
		       is_zero_1           ? {I_WIDTH{1'b0}} :			// zero
		       is_nan_1            ? {I_WIDTH{1'b1}} :			// NaN
		       is_inf_1 && ~sign_1 ? {I_WIDTH{1'b1}} :			// +inf
		       is_inf_1 &&  sign_1 ? {I_WIDTH{1'b0}} :			// -inf
		       is_min_1            ? {I_WIDTH{1'b0}} :			// num < 1.0
		       is_oor_1 && ~sign_1 ? {I_WIDTH{1'b1}} :			// num > int_max
		       is_oor_1 &&  sign_1 ? {I_WIDTH{1'b0}} :			// num < int_min
		       sign_1              ? {I_WIDTH{1'b0}} : rnd_flac_1;

		out.invalid =
			 is_zero_1         ? 1'b0 :
		         is_nan_1          ? 1'b1 :
		         is_inf_1          ? 1'b1 :
			 is_min_1          ? 1'b0 :
			 is_oor_1          ? 1'b1 :
			 sign_1            ? 1'b1 : 1'b0;

		out.inexact =
			 is_zero_1         ? 1'b0 :
		         is_nan_1          ? 1'b0 :
		         is_inf_1          ? 1'b0 :
			 is_min_1          ? 1'b1 :
			 is_oor_1          ? 1'b0 :
			 sign_1            ? 1'b0 :
			 |sft_flac_1[F_FLAC-1:0] ? 1'b1 : 1'b0;

	endtask

endclass : FCVT_W_D;

`endif	// _fcvt_w_d_sv_
