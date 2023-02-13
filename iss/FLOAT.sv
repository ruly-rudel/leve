`ifndef _float_sv_
`define _float_sv_

`include "defs.vh"

typedef struct packed {
	bit [31:0]	val;
	bit		inexact;
	bit		invalid;
} float_t;

typedef struct packed {
	bit [63:0]	val;
	bit		inexact;
	bit		invalid;
} double_t;

typedef struct packed {
	bit [31:0]	val;
	bit		inexact;
	bit		invalid;
} word_t;

typedef struct packed {
	bit [63:0]	val;
	bit		inexact;
	bit		invalid;
} long_t;

class FLOAT
#(
	parameter type	T = float_t,
	parameter	F_WIDTH = 32,
	parameter	F_EXP   = 8,
	parameter	F_FLAC  = 23
);

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
	

	function [F_EXP-1:0] first_1(input [F_FLAC+1:0] in);
		for(integer i = 0; i < F_FLAC + 1; i = i + 1) begin
			if(|(1 << (F_FLAC + 1 - i) & in)) begin
				return i[F_EXP-1:0];
			end
		end
		return {F_EXP{1'b1}};
	endfunction

	function last_n_dirty(input [F_FLAC-1:0] in, input [F_EXP-1:0] mag_shift);
		bit [F_FLAC-1:0]	mask = ('b1 << mag_shift) - 'b1;
		return |(in & mask);
	endfunction


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

	task fadd
	(
		input [F_WIDTH-1:0]		in1,
		input [F_WIDTH-1:0]		in2,
		output T			out
	);

		bit 			mm_swap;
		bit			mm_is_zero_1, mm_is_zero_2;
		bit			mm_sign_1, mm_sign_2;
		bit [F_EXP-1:0]		mm_exp_1,  mm_exp_2;
		bit [F_FLAC-1:0]	mm_flac_1, mm_flac_2;
	
		bit [F_EXP-1:0]		mag_shift;
		bit			sf_sign_1, sf_sign_2;
		bit [F_EXP-1:0]		sf_exp_1, sf_exp_2;
		bit [F_FLAC:0]		sf_flac_1, sf_flac_2;
	
		bit [F_EXP-1:0]		cm_exp_1,  cm_exp_2;
		bit [F_FLAC+1:0]	cm_flac_1, cm_flac_2;
	
		bit [F_EXP-1:0]		add_exp;
		bit [F_FLAC+2:0]	add_flac;
	
		bit			abs_sign;
		bit [F_EXP-1:0]		abs_exp;
		bit [F_FLAC+1:0]	abs_flac;
	
		bit [F_EXP-1:0]		norm_shift;
		bit			norm_is_zero;
		bit			norm_sign;
		bit [F_EXP-1:0]		norm_exp;
		bit [F_FLAC+1:0]	norm_flac;
	
		bit			round_sign;
		bit [F_EXP-1:0]		round_exp;
		bit [F_FLAC-1:0]	round_flac;
	
		bit [F_WIDTH-1:0]	add_f;

		// parse
		parse(in1, in2);

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
		add_flac  = {cm_flac_1[F_FLAC+1], cm_flac_1} + {cm_flac_2[F_FLAC+1], cm_flac_2};

		// abs
		abs_sign   = add_flac[F_FLAC+2];
		abs_exp    = add_exp;
		abs_flac   = abs_sign ? ~add_flac[F_FLAC+1:0] + 'b1 : add_flac[F_FLAC+1:0];

		// normalize
		norm_shift = first_1(abs_flac);
		norm_is_zero = norm_shift == {F_EXP{1'b1}} ? 1'b1 : 1'b0;
		norm_sign  = abs_sign;
		norm_exp   = abs_exp - norm_shift + 'h1;
		norm_flac  = abs_flac << norm_shift;

		// round
		round_sign = norm_sign;
		round_exp  = norm_exp;
		round_flac = norm_flac[F_FLAC:1];

		// result
		add_f = {round_sign, round_exp, round_flac};
	
		out.val =
		      is_inf_1  && is_inf_2 && (sign_1 ^ sign_2) ? {1'b0, {F_EXP+1{1'b1}}, {F_FLAC-1{1'b0}}} :	// inf-inf or -inf+inf = qNaN
		      is_nan_1  || is_nan_2  ? {1'b0, {F_EXP+1{1'b1}}, {F_FLAC-1{1'b0}}} :	// NaN + any = NaN, any + NaN = NaN
		      is_inf_1               ? in1 :						// +-inf + (any) = +-inf
		      is_inf_2               ? in2 :						// (any) + +-inf = +-inf
		      is_zero_1 && is_zero_2 ? {F_WIDTH{1'b0}} :				// +-0   + +-0   = +0
		      is_zero_1 && is_num_2  ? in2 :						// +-0   + num	 = num
		      is_zero_2 && is_num_1  ? in1 :						// num   + +-0   = num
		      norm_is_zero           ? {F_WIDTH{1'b0}} :				// flac is zero
						add_f;
		out.inexact = norm_flac[0] | (mag_shift > 0 ? last_n_dirty(mm_flac_2, mag_shift) : 1'b0);
		out.invalid = is_inf_1  && is_inf_2 && (sign_1 ^ sign_2) ||
			  is_nan_1  || is_nan_2 ? 1'b1 : 1'b0;

	endtask

	task fsub
	(
		input [F_WIDTH-1:0]		in1,
		input [F_WIDTH-1:0]		in2,
		output T			out
	);
		fadd(in1, {~in2[F_WIDTH-1], in2[F_WIDTH-2:0]}, out);
	endtask

	task fmul
	(
		input [F_WIDTH-1:0]		in1,
		input [F_WIDTH-1:0]		in2,
		output T			out
	);
		bit			mul_sign;
		bit [F_EXP+1:0]		mul_exp;
		bit [(F_FLAC+1)*2-1:0]	mul_flac;
	
		bit [F_EXP+1:0]		norm_exp;
		bit [(F_FLAC+1)*2-1:0]	norm_flac;
	
		bit [F_EXP+1:0]		round_exp;
		bit [F_FLAC:0]		round_flac;
	
		bit [F_WIDTH-1:0]	mul_f;

		// parse
		parse(in1, in2);
	
		// multiply
		mul_sign  = sign_1 ^ sign_2;
		mul_exp   = {1'h0, exp_1} + {1'h0, exp_2} - ((1 << (F_EXP -1)) - 1);
		mul_flac  = {1'b1, flac_1} * {1'b1, flac_2};
	
		// normalize
		if(mul_flac[(F_FLAC+1)*2-1]) begin
			norm_exp  = mul_exp + 'b1;
			norm_flac = mul_flac;
		end else if (~mul_flac[(F_FLAC+1)*2-1] & mul_flac[(F_FLAC+1)*2-2]) begin
			norm_exp  = mul_exp;
			norm_flac = {mul_flac[(F_FLAC+1)*2-2:0], 1'b0};
		end else begin
			norm_exp  = mul_exp + 1'b1;
			norm_flac = mul_flac;
		end
	
		// round
		round_exp  = norm_exp;
		round_flac = norm_flac[(F_FLAC+1)*2-1:(F_FLAC+1)*2-F_FLAC-1];

		// result
		mul_f = is_nan_1  || is_nan_2       ? {1'b0, {F_EXP+1{1'b1}}, {F_FLAC-1{1'b0}}} :		// NaN   * any   = NaN, any * NaN = NaN
			is_zero_1 && is_inf_2       ? {1'b0, {F_EXP+1{1'b1}}, {F_FLAC-1{1'b0}}} :			// +-0   * +-inf = NaN
			is_zero_2 && is_inf_1       ? {1'b0, {F_EXP+1{1'b1}}, {F_FLAC-1{1'b0}}} :			// +-inf * +-0   = NaN
			is_zero_1 || is_zero_2      ? {mul_sign, {F_EXP{1'b0}}, {F_FLAC{1'b0}}} :		// +-0   * +-0   = +-0
			is_inf_1  && is_inf_2       ? {mul_sign, {F_EXP{1'b1}}, {F_FLAC{1'b0}}} :		// +-inf * +-inf = +-inf
			$signed(round_exp) >= ((1<<F_EXP) - 1)							// inf
						    ? {mul_sign, {F_EXP{1'b1}}, {F_FLAC{1'b0}}} :
			round_exp[F_EXP+1]          ? {mul_sign, {F_EXP{1'b0}}, round_flac[F_FLAC:1]} :		// subnormal number
						      {mul_sign, round_exp[F_EXP-1:0], round_flac[F_FLAC-1:0]};
	
		out.val = mul_f;
		out.invalid = is_inf_1  && is_zero_2	? 1'b0 :
		              is_inf_2  && is_zero_1	? 1'b0 :
			      is_nan_1  || is_nan_2	? 1'b1 : 1'b0;
		out.inexact = |norm_flac[F_FLAC:0];
	endtask


	function [31:0] fclass
	(
		input [F_WIDTH-1:0]		in1,
	);
		bit [9:0]	out_w, out_w2;

		// parse
		parse(in1, in1);

		out_w[0] =  sign_1 && is_inf_1  ? 1'b1 : 1'b0;
		out_w[1] =  1'b0;
		out_w[2] =  sign_1 && is_sub_1  ? 1'b1 : 1'b0;
		out_w[3] =  sign_1 && is_zero_1 ? 1'b1 : 1'b0;
		out_w[4] = ~sign_1 && is_zero_1 ? 1'b1 : 1'b0;
		out_w[5] = ~sign_1 && is_sub_1  ? 1'b1 : 1'b0;
		out_w[6] =  1'b0;
		out_w[7] = ~sign_1 && is_inf_1  ? 1'b1 : 1'b0;
		out_w[8] =            is_snan_1 ? 1'b1 : 1'b0;
		out_w[9] =            is_qnan_1 ? 1'b1 : 1'b0;

		out_w2[0] = out_w[0];
		out_w2[1] =  sign_1 && ~out_w[0] && ~out_w[2] && ~out_w[3] && ~out_w[8] && ~out_w[9] ? 1'b1 : 1'b0;
		out_w2[2] = out_w[2];
		out_w2[3] = out_w[3];
		out_w2[4] = out_w[4];
		out_w2[5] = out_w[5];
		out_w2[6] = ~sign_1 && ~out_w[4] && ~out_w[5] && ~out_w[7] && ~out_w[8] && ~out_w[9] ? 1'b1 : 1'b0;
		out_w2[7] = out_w[7];
		out_w2[8] = out_w[8];
		out_w2[9] = out_w[9];

		return {{22{1'b0}}, out_w2};
	endfunction

	task feq
	(
		input [F_WIDTH-1:0]		in1,
		input [F_WIDTH-1:0]		in2,
		output word_t			out
	);
		// parse
		parse(in1, in2);

		out.val =
		     is_zero_1 && is_zero_2 ||				// +-0.0 == +-0.0
		     is_inf_1  && is_inf_2  && sign_1 == sign_2 ||	// inf == inf, -inf == -inf
		     is_num_1  && is_num_2  && in1 == in2 		// bit exact equal, not NaN
		     	? {{31{1'b0}}, 1'b1} : {32{1'b0}};

		out.invalid = is_snan_1 | is_snan_2;
		out.inexact = 1'b0;
	endtask

	task flt
	(
		input [F_WIDTH-1:0]		in1,
		input [F_WIDTH-1:0]		in2,
		output word_t			out
	);
		bit		less_than;
		T		sub;

		fsub(in1, in2, sub);
		less_than = sub.val[F_WIDTH-1];

		// parse
		parse(in1, in2);

		out.val =
		     is_num_1  && is_num_2  && less_than ||
		     is_num_1  && is_inf_2  && ~sign_2   ||		// num < +inf
		     is_num_1  && sign_1    && is_zero_2 ||		// num(minus) < +-0
		     is_inf_1  && sign_1    && is_num_2  ||		// -inf < num
		     is_inf_1  && sign_1    && is_inf_2  && ~sign_2  ||	// -inf < +inf
		     is_inf_1  && sign_1    && is_zero_2 ||		// -inf < +-0
		     is_zero_1 && is_num_2  && ~sign_2   ||		// +-0 < num(plus)
		     is_zero_1 && is_inf_2  && ~sign_2   		// +-0 < +inf
		     	? {{31{1'b0}}, 1'b1} : {32{1'b0}};


		out.invalid = is_nan_1 | is_nan_2;
		out.inexact = 1'b0;
	endtask

	task fle
	(
		input [F_WIDTH-1:0]		in1,
		input [F_WIDTH-1:0]		in2,
		output word_t			out
	);
		word_t				out1;
		word_t				out2;

		feq(in1, in2, out1);
		flt(in1, in2, out2);
		out.val = out1.val | out2.val;
		out.invalid = out2.invalid;
		out.inexact = 1'b0;
	endtask

	task fmax
	(
		input [F_WIDTH-1:0]		in1,
		input [F_WIDTH-1:0]		in2,
		output T			out
	);
		T				sub;
		bit				less_than;
		bit [F_WIDTH-1:0]		max;

		fsub(in1, in2, sub);
		less_than = sub.val[F_WIDTH-1];

		if(is_nan_1) begin			// in1 = NaN
			if(is_nan_2) begin
					max = {1'b0, {F_EXP{1'b1}}, 1'b1, {F_FLAC-1{1'b0}}};	// qNaN
			end else begin
					max = in2;
			end
		end else if(is_nan_2) begin		// in2 = NaN
					max = in1;
		end else if(is_inf_1) begin
			if(sign_1) begin		// in1 = -inf, in2 = any, not NaN
					max = in2;
			end else begin			// in1 = +inf, in2 = any, not NaN
					max = in1;
			end
		end else if (is_zero_1) begin
			if(is_zero_2) begin
				if(sign_1) begin	// in1 = -0, in2 = +-0
					max = in2;
				end else begin		// in1 = +0, in2 = +-0
					max = in1;
				end
			end else begin
				if(sign_2) begin	// in1 = +-0, in2 = -inf, -NUM
					max = in1;
				end else begin		// in1 = +-0, in2 = +inf, +NUM
					max = in2;
				end
			end
		end else begin
			if(less_than) begin		// in1 < in2
					max = in2;
			end else begin
					max = in1;
			end
		end

		out.val = max;
		out.invalid = is_snan_1  | is_snan_2;
		out.inexact = 1'b0;
	endtask

	task fmin
	(
		input [F_WIDTH-1:0]		in1,
		input [F_WIDTH-1:0]		in2,
		output T			out
	);
		T				sub;
		bit				less_than;
		bit [F_WIDTH-1:0]		min;

		fsub(in1, in2, sub);
		less_than = sub.val[F_WIDTH-1];

		if(is_nan_1) begin			// in1 = NaN
			if(is_nan_2) begin
					min = {1'b0, {F_EXP{1'b1}}, 1'b1, {F_FLAC-1{1'b0}}};	// qNaN
			end else begin
					min = in2;
			end
		end else if(is_nan_2) begin		// in2 = NaN
					min = in1;
		end else if(is_inf_1) begin
			if(sign_1) begin		// in1 = -inf, in2 = any, not NaN
					min = in1;
			end else begin			// in1 = +inf, in2 = any, not NaN
					min = in2;
			end
		end else if (is_zero_1) begin
			if(is_zero_2) begin
				if(sign_1) begin	// in1 = -0, in2 = +-0
					min = in1;
				end else begin		// in1 = +0, in2 = +-0
					min = in2;
				end
			end else begin
				if(sign_2) begin	// in1 = +-0, in2 = -inf, -NUM
					min = in2;
				end else begin		// in1 = +-0, in2 = +inf, +NUM
					min = in1;
				end
			end
		end else begin
			if(less_than) begin		// in1 < in2
					min = in1;
			end else begin
					min = in2;
			end
		end

		out.val = min;
		out.invalid = is_snan_1  | is_snan_2;
		out.inexact = 1'b0;
	endtask

endclass: FLOAT;

`endif	// _float_sv_
