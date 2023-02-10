`ifndef _float_sv_
`define _float_sv_

`include "defs.vh"

typedef struct packed {
	logic [31:0]	val;
	logic		inexact;
	logic		invalid;
} float_t;

class FLOAT
#(
	parameter type	T = float_t,
	parameter	F_WIDTH = 32,
	parameter	F_EXP   = 8,
	parameter	F_FLAC  = 23
);

	logic 			sign_1, sign_2;
	logic [F_EXP-1:0]	exp_1, exp_2;
	logic [F_FLAC-1:0]	flac_1, flac_2;
	logic			is_zero_1, is_zero_2;
	logic			is_nan_1, is_nan_2;
	logic			is_inf_1, is_inf_2;
	logic			is_qnan_1, is_qnan_2;
	logic			is_snan_1, is_snan_2;
	logic			is_num_1, is_num_2;
	logic			is_sub_1, is_sub_2;
	

	function [4:0] first_1_25(input [24:0] in);
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
	endfunction
	
	function last_n_dirty_23(input [22:0] in, input [7:0] mag_shift);
		logic [22:0]	mask;
		mask = ('b1 << mag_shift) - 'b1;
		last_n_dirty_23 = |(in & mask);
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

	function T fadd
	(
		input [F_WIDTH-1:0]		in1,
		input [F_WIDTH-1:0]		in2
	);
		T			out;

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
		out.inexact = norm_flac[0] | (mag_shift > 0 ? last_n_dirty_23(mm_flac_2, mag_shift) : 1'b0);
		out.invalid = is_inf_1  && is_inf_2 && (sign_1 ^ sign_2) ||
			  is_nan_1  || is_nan_2 ? 1'b1 : 1'b0;

		return out;

	endfunction

	function T fsub
	(
		input [F_WIDTH-1:0]		in1,
		input [F_WIDTH-1:0]		in2
	);
		return fadd(in1, {~in2[F_WIDTH-1], in2[F_WIDTH-2:0]});

	endfunction

	function T fmul
	(
		input [F_WIDTH-1:0]		in1,
		input [F_WIDTH-1:0]		in2
	);
		T				out;

		logic				mul_sign;
		logic [F_EXP+1:0]		mul_exp;
		logic [(F_FLAC+1)*2-1:0]	mul_flac;
	
		logic [F_EXP+1:0]		norm_exp;
		logic [(F_FLAC+1)*2-1:0]	norm_flac;
	
		logic [F_EXP+1:0]		round_exp;
		logic [F_FLAC:0]		round_flac;
	
		logic [F_WIDTH-1:0]		mul_f;

		// parse
		parse(in1, in2);
	
		// multiply
		mul_sign  = sign_1 ^ sign_2;
		mul_exp   = {1'h0, exp_1} + {1'h0, exp_2} - 10'd127;
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
	
		out.val = mul_f;
		out.invalid = is_inf_1  && is_zero_2	? 1'b0 :
		              is_inf_2  && is_zero_1	? 1'b0 :
			      is_nan_1  || is_nan_2	? 1'b1 : 1'b0;
		out.inexact = |norm_flac[F_FLAC:0];

		return out;

	endfunction


	function [31:0] fclass
	(
		input [F_WIDTH-1:0]		in1,
	);
		logic [9:0]	out_w, out_w2;

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

	function T feq
	(
		input [F_WIDTH-1:0]		in1,
		input [F_WIDTH-1:0]		in2
	);
		T				out;

		// parse
		parse(in1, in2);

		out.val =
		     is_zero_1 && is_zero_2 ||				// +-0.0 == +-0.0
		     is_inf_1  && is_inf_2  && sign_1 == sign_2 ||	// inf == inf, -inf == -inf
		     is_num_1  && is_num_2  && in1 == in2 		// bit exact equal, not NaN
		     	? {{31{1'b0}}, 1'b1} : {32{1'b0}};

		out.invalid = is_snan_1 | is_snan_2;
		out.inexact = 1'b0;

		return out;
	endfunction

	function T flt
	(
		input [F_WIDTH-1:0]		in1,
		input [F_WIDTH-1:0]		in2
	);
		T				out;

		logic		less_than;
		T		sub;

		sub = fsub(in1, in2);
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

		return out;
	endfunction

	function T fle
	(
		input [F_WIDTH-1:0]		in1,
		input [F_WIDTH-1:0]		in2
	);
		T				out1;
		T				out2;
		T				out;

		out1 = feq(in1, in2);
		out2 = flt(in1, in2);
		out.val = out1.val | out2.val;
		out.invalid = out2.invalid;
		out.inexact = 1'b0;

		return out;
	endfunction

	function T fmax
	(
		input [F_WIDTH-1:0]		in1,
		input [F_WIDTH-1:0]		in2
	);
		T				out;

		T				sub;
		logic				less_than;
		logic [F_WIDTH-1:0]		max;

		sub = fsub(in1, in2);
		less_than = sub.val[F_WIDTH-1];

		if(is_nan_1) begin			// in1 = NaN
			if(is_nan_2) begin
					max = {1'b0, {8{1'b1}}, 1'b1, {22{1'b0}}};	// qNaN
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

		return out;
	endfunction

	function T fmin
	(
		input [F_WIDTH-1:0]		in1,
		input [F_WIDTH-1:0]		in2
	);
		T				out;

		T				sub;
		logic				less_than;
		logic [F_WIDTH-1:0]		min;

		sub = fsub(in1, in2);
		less_than = sub.val[F_WIDTH-1];

		if(is_nan_1) begin			// in1 = NaN
			if(is_nan_2) begin
					min = {1'b0, {8{1'b1}}, 1'b1, {22{1'b0}}};	// qNaN
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

		return out;
	endfunction

endclass: FLOAT;

`endif	// _float_sv_