
`include "defs.vh"

module FMAX_F
(
	input [31:0]		in1,
	input [31:0]		in2,

	output logic [31:0]	max,

	output logic		invalid
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

		invalid = is_snan_1  | is_snan_2;
	end

endmodule

