
module RISCV64G_ISS_CSR
(
	input				CLK,
	input				RSTn,

	input				WE,
	input [12-1:0]			A,
	output logic [`XLEN-1:0]	RD,
	input [`XLEN-1:0]		WD,

	output [`XLEN-1:0]		mtvec,
	output [`XLEN-1:0]		mepc,

	input				trap
);

	reg [`XLEN-1:0]		csr_reg[0:`NUM_CSR-1];

	always_comb
	begin
		case (A)
		12'hf14:	RD = 64'h0000_0000_0000_0000;
		default:	RD = csr_reg[A];
		endcase
	end

	always_ff @(posedge CLK or negedge RSTn)
	begin
		if(!RSTn) begin
			integer i;
			for(i = 0; i < `NUM_CSR; i = i + 1) begin
				csr_reg[i] = {`XLEN{1'b0}};
			end
		end else begin
			if(WE) begin
				csr_reg[A] <= WD;
			end else if (trap) begin	// TRAP
				csr_reg[12'h342] <= 64'h0000_0000_0000_000b;	// mcause
			end
		end
	end

	assign	mtvec = csr_reg[12'h305];
	assign	mepc  = csr_reg[12'h341];

endmodule
