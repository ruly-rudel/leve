
`include "defs.vh"

module FCLASS_F
(
	input [31:0]		in1,
	output logic [31:0]	out
);
	logic 		sign_1;
	logic [7:0]	exp_1;
	logic [22:0]	flac_1;
	logic		is_zero_1;
	logic		is_nan_1;
	logic		is_inf_1;
	logic		is_sub_1;
	logic		is_quiet_1;


	always_comb begin
		// parse
		sign_1     = in1[31];
		exp_1      = in1[30:23];
		flac_1     = in1[22:0];

		is_zero_1  = exp_1 == 8'h00 && ~|flac_1 ? 1'b1 : 1'b0;
		is_nan_1   = exp_1 == 8'hff &&  |flac_1 ? 1'b1 : 1'b0;
		is_inf_1   = exp_1 == 8'hff && ~|flac_1 ? 1'b1 : 1'b0;
		is_sub_1   = exp_1 == 8'h00 &&  |flac_1 ? 1'b1 : 1'b0;
		is_quiet_1 = in1[22];

	end

	wire [9:0] out_w, out_w2;
	assign out_w[0] =  sign_1 && is_inf_1  ? 1'b1 : 1'b0;
	assign out_w[2] =  sign_1 && is_sub_1  ? 1'b1 : 1'b0;
	assign out_w[3] =  sign_1 && is_zero_1 ? 1'b1 : 1'b0;
	assign out_w[4] = ~sign_1 && is_zero_1 ? 1'b1 : 1'b0;
	assign out_w[5] = ~sign_1 && is_sub_1  ? 1'b1 : 1'b0;
	assign out_w[7] = ~sign_1 && is_inf_1  ? 1'b1 : 1'b0;
	assign out_w[8] = ~is_quiet_1 && is_nan_1  ? 1'b1 : 1'b0;
	assign out_w[9] =  is_quiet_1 && is_nan_1  ? 1'b1 : 1'b0;

	assign out_w2[0] = out_w[0];
	assign out_w2[1] =  sign_1 && ~out_w[0] && ~out_w[2] && ~out_w[3] && ~out_w[8] && ~out_w[9] ? 1'b1 : 1'b0;
	assign out_w2[2] = out_w[2];
	assign out_w2[3] = out_w[3];
	assign out_w2[4] = out_w[4];
	assign out_w2[5] = out_w[5];
	assign out_w2[6] = ~sign_1 && ~out_w[4] && ~out_w[5] && ~out_w[7] && ~out_w[8] && ~out_w[9] ? 1'b1 : 1'b0;
	assign out_w2[7] = out_w[7];
	assign out_w2[8] = out_w[8];
	assign out_w2[9] = out_w[9];

	assign out = {{22{1'b0}}, out_w2};

endmodule

