
`include "defs.vh"

module FCMP_F
(
	input [31:0]		in1,
	input [31:0]		in2,

	output logic		eq,
	output logic		lt,
	output logic		le,

	output logic		eq_invalid,
	output logic		lt_invalid
);

	logic 		sign_1, sign_2;
	logic [7:0]	exp_1, exp_2;
	logic [22:0]	flac_1, flac_2;
	logic		is_zero_1, is_zero_2;
	logic		is_nan_1, is_nan_2;
	logic		is_snan_1, is_snan_2;
	logic		is_qnan_1, is_qnan_2;
	logic		is_inf_1, is_inf_2;
	logic		is_num_1, is_num_2;

	wire [31:0]		out;
	wire		less_than;

	FADD_F	FSUB_F
	(
		.in1		(in1),
		.in2		({~in2[31], in2[30:0]}),
		.out		(out),
		.inexact	(),
		.invalid	()
	);

	assign less_than = out[31];

	always_comb begin
		// parse
		sign_1    = in1[31];
		exp_1     = in1[30:23];
		flac_1    = in1[22:0];
		is_zero_1 = exp_1 == 8'h00 && ~|flac_1 ? 1'b1 : 1'b0;
		is_nan_1  = exp_1 == 8'hff &&  |flac_1 ? 1'b1 : 1'b0;
		is_inf_1  = exp_1 == 8'hff && ~|flac_1 ? 1'b1 : 1'b0;
		is_snan_1 = is_nan_1 && ~flac_1[22]    ? 1'b1 : 1'b0;
		is_qnan_1 = is_nan_1 &&  flac_1[22]    ? 1'b1 : 1'b0;
		is_num_1  = exp_1 != 8'h00 && exp_1 != 8'hff ? 1'b1 : 1'b0;
	
		sign_2    = in2[31];
		exp_2     = in2[30:23];
		flac_2    = in2[22:0];
		is_zero_2 = exp_2 == 8'h00 && ~|flac_2 ? 1'b1 : 1'b0;
		is_nan_2  = exp_2 == 8'hff &&  |flac_2 ? 1'b1 : 1'b0;
		is_inf_2  = exp_2 == 8'hff && ~|flac_2 ? 1'b1 : 1'b0;
		is_snan_2 = is_nan_2 && ~flac_2[22];
		is_qnan_2 = is_nan_2 &&  flac_2[22];
		is_num_2  = exp_2 != 8'h00 && exp_2 != 8'hff ? 1'b1 : 1'b0;


		eq = is_zero_1 && is_zero_2 ||				// +-0.0 == +-0.0
		     is_inf_1  && is_inf_2  && sign_1 == sign_2 ||	// inf == inf, -inf == -inf
		     is_num_1  && is_num_2  && in1 == in2 		// bit exact equal, not NaN
		     	? 1'b1 : 1'b0;

		lt = is_num_1  && is_num_2  && less_than ||
		     is_num_1  && is_inf_2  && ~sign_2   ||		// num < +inf
		     is_num_1  && sign_1    && is_zero_2 ||		// num(minus) < +-0
		     is_inf_1  && sign_1    && is_num_2  ||		// -inf < num
		     is_inf_1  && sign_1    && is_inf_2  && ~sign_2  ||	// -inf < +inf
		     is_inf_1  && sign_1    && is_zero_2 ||		// -inf < +-0
		     is_zero_1 && is_num_2  && ~sign_2   ||		// +-0 < num(plus)
		     is_zero_1 && is_inf_2  && ~sign_2   ? 1'b1 : 1'b0;	// +-0 < +inf

	     	le = eq | lt;

		eq_invalid = is_snan_1 | is_snan_2;
		lt_invalid = is_nan_1  | is_nan_2;
	end

endmodule

