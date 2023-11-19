
`include "defs.vh"
`include "AXI.sv"

typedef struct packed {
	logic			valid;
	logic [`XLEN-1:0]	tag;
	logic [128*4-1:0]	data;
} ibuf_t;

`define IB_WAY	2

module LEVE1_IF
(
	input				CLK,
	input		 		RSTn,

	output logic			OVALID,
	input				OREADY,
	output logic [`XLEN-1:0]	OPC,
	output logic [31:0]		OINSTR,

	AXIR.init			RII	// read initiator: instruction
);
	// stage 1:
	logic [6:0]		opcode_s1;
	logic [`XLEN-1:0]	imm_j_s1;
	logic			jal_s1;
	logic [`XLEN-1:0]	pc;
	logic 			ibuf_hit;
	always_ff @(posedge CLK or negedge RSTn) begin
		if(!RSTn) begin
			pc		<= 64'h0000_0000_8000_0000;
		end else if(ibuf_hit && OREADY) begin
			if(jal_s1) begin
				pc <= pc + imm_j_s1;
			end else begin
				pc <= pc + 'h4;
			end
		end
	end

	logic [2:0]		rii_st;
	logic [$clog2(`IB_WAY)-1:0]	ibuf_hit_sel;
	logic 			ibuf_miss;
	logic [$clog2(`IB_WAY)-1:0]	ibuf_miss_sel;
	ibuf_t	ibuf[0:`IB_WAY-1];
	always_ff @(posedge CLK or negedge RSTn) begin
		if(!RSTn) begin
			for(integer i = 0; i < `IB_WAY; i++) begin
				ibuf[i].valid = 1'b0;
			end
		end else if(rii_st[2] == 1'b1) begin
			if(RII.r_est()) begin
				case(rii_st[1:0])
					2'h0: ibuf[ibuf_miss_sel].data[127:0]   <= RII.RDATA;
					2'h1: ibuf[ibuf_miss_sel].data[255:128] <= RII.RDATA;
					2'h2: ibuf[ibuf_miss_sel].data[383:256] <= RII.RDATA;
					2'h3: ibuf[ibuf_miss_sel].data[511:384] <= RII.RDATA;
				endcase
				if(RII.RLAST) begin
					ibuf[ibuf_miss_sel].valid = 1'b1;
					ibuf[ibuf_miss_sel].tag = pc;
				end
			end
		end
	end

	//logic [$clog2(`IB_WAY):0]	ibuf_hit;
	logic [127:0]		instr1;
	logic [31:0]		instr;

	always_comb begin
		logic	hit;
		ibuf_hit = 1'b0;
		ibuf_hit_sel = {$clog2(`IB_WAY){1'b0}};
		for(integer i = 0; i < `IB_WAY; i++) begin
			hit		= ibuf[i].valid && ibuf[i].tag[63:6] == pc[63:6];
			ibuf_hit	= ibuf_hit || hit;
			ibuf_hit_sel	= hit ? i[$clog2(`IB_WAY)-1:0] : ibuf_hit_sel;
		end

		ibuf_miss = ~ibuf_hit;
		ibuf_miss_sel = ibuf_hit_sel + 1'b1;

		case (pc[5:4])
			2'h0: instr1 = ibuf[ibuf_hit_sel].data[127:0];
			2'h1: instr1 = ibuf[ibuf_hit_sel].data[255:128];
			2'h2: instr1 = ibuf[ibuf_hit_sel].data[383:256];
			2'h3: instr1 = ibuf[ibuf_hit_sel].data[511:384];
		endcase

		case (pc[3:2])
			2'h0: instr = instr1[31:0];
			2'h1: instr = instr1[63:32];
			2'h2: instr = instr1[95:64];
			2'h3: instr = instr1[127:96];
		endcase
	end

	wire [1:0] tmp = rii_st[1:0] + 1'b1;
	always_ff @(posedge CLK or negedge RSTn) begin
		if(!RSTn) begin
			rii_st	<= 3'h0;
		end else begin
			if(rii_st == 3'h0) begin
				if(RII.ar_est()) begin
					rii_st <= {1'b1, pc[5:4]};
				end
			end else begin
				if(RII.r_est()) begin
					if(RII.RLAST) begin
						rii_st <= 3'h0;
					end else begin
						rii_st <= {1'b1, tmp};
					end
				end
			end
		end
	end
	
	always_comb begin
		RII.ARVALID	= rii_st == 3'h0 && ibuf_miss;
		RII.ARADDR	= pc[31:0];
		RII.ARBURST	= `AXI_BURST_WRAP;
		RII.ARLEN	= 8'd3;

		RII.RREADY	= 1'b1;
	end

	// decode JAL
	always_comb begin
		opcode_s1	= instr[6:0];
		imm_j_s1	= {{11+32{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
		jal_s1		= opcode_s1 == 7'b11_011_11 ? 1'b1 : 1'b0;	// JAL
	end

	always_ff @(posedge CLK or negedge RSTn) begin
		if(!RSTn) begin
			OVALID	<= 1'b0;
		end else begin
			OVALID	<= ibuf_hit;
			OPC	<= pc;
			OINSTR	<= instr;
		end
	end

endmodule
