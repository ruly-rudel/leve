
`include "defs.vh"

module FMUL_F
(
	input [31:0]		in1,
	input [31:0]		in2,
	output logic [31:0]	out,
	output logic		inexact
);
	logic 		sign_1, sign_2;
	logic [7:0]	exp_1, exp_2;
	logic [22:0]	flac_1, flac_2;
	logic		is_zero_1, is_zero_2;
	logic		is_nan_1, is_nan_2;

	logic		mul_sign;
	logic [9:0]	mul_exp;
	logic [47:0]	mul_flac;

	logic [9:0]	norm_exp;
	logic [47:0]	norm_flac;

	logic [9:0]	round_exp;
	logic [23:0]	round_flac;

	logic [31:0]	mul_f;

	always_comb begin
		// parse
		sign_1    = in1[31];
		exp_1     = in1[30:23];
		flac_1    = in1[22:0];
		is_zero_1 = exp_1 == 8'h00 && flac_1 == 23'h00_0000 ? 1'b1 : 1'b0;
		is_nan_1  = exp_1 == 8'hff && |flac_1 ? 1'b1 : 1'b0;
	
		sign_2    = in2[31];
		exp_2     = in2[30:23];
		flac_2    = in2[22:0];
		is_zero_2 = exp_2 == 8'h00 && flac_2 == 23'h00_0000 ? 1'b1 : 1'b0;
		is_nan_2  = exp_2 == 8'hff && |flac_2 ? 1'b1 : 1'b0;
	
		// multiply
		mul_sign  = sign_1 ^ sign_2;
		mul_exp   = {1'h0, exp_1} + {1'h0, exp_2} - 10'd127;
		mul_flac  = {1'b1, flac_1} * {1'b1, flac_2};
	
		// normalize
		if(mul_flac[47]) 
		begin
			norm_exp  = mul_exp + 'b1;
			norm_flac = mul_flac;
		end
	       	else if (~mul_flac[47] & mul_flac[46])
		begin
			norm_exp  = mul_exp;
			norm_flac = {mul_flac[46:0], 1'b0};
		end else begin
			norm_exp  = mul_exp + 1'b1;
			norm_flac = mul_flac;
		end
	
		// round
		round_exp  = norm_exp;
		round_flac = norm_flac[47:24];
	
		// result
		mul_f = is_zero_1 || is_zero_2      ? {mul_sign, 8'h00, 23'h00_0000} :	// zero
		        is_nan_1                    ? in1 :				// NaN
		        is_nan_2                    ? in2 :				// NaN
			$signed(round_exp) >= 'd255 ? {mul_sign, 8'hff, 23'h00_0000} :	// inf
			round_exp[9]                ? {mul_sign, 8'h00, round_flac[22:0]} :	// unnormalized number
						 {mul_sign, round_exp[7:0], round_flac[22:0]};
	
		out = mul_f;
		inexact = |norm_flac[23:0];
	end

endmodule

