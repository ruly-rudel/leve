
`include "defs.vh"

parameter IB_WAY = 2;

typedef struct packed {
	logic				valid;
	logic [`XLEN-1:0]		tag;
	union packed {
		logic [4:0][128-1:0]	w128;
		logic [16:0][32-1:0]	w32;
	} data;
} ibuf_t;

function logic is_hit(input ibuf_t ibuf, input [`XLEN-1:0] pc);
	return ibuf.valid && ibuf.tag[63:6] == pc[63:6];
endfunction

module LEVE1_IF
(
	input				CLK,
	input		 		RSTn,

	input				IPC_WE,
	input [`XLEN-1:0]		INEXT_PC,

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
	logic 			hit;
	always_ff @(posedge CLK or negedge RSTn) begin
		if(!RSTn) begin
			pc		<= 64'h0000_0000_8000_0000;
		end else if(IPC_WE) begin
				pc <= INEXT_PC;
		end else if(hit && OREADY) begin
			if(jal_s1) begin
				pc <= $bits(pc)'(pc + imm_j_s1);
			end else begin
				pc <= $bits(pc)'(pc + 'h4);
			end
		end
	end

	logic [2:0]		rii_st;
	logic [$clog2(IB_WAY)-1:0]	hit_sel;
	logic 			miss;
	logic [$clog2(IB_WAY)-1:0]	miss_sel;
	ibuf_t	[IB_WAY-1:0] ibuf;
	always_ff @(posedge CLK or negedge RSTn) begin
		if(!RSTn) begin
			for(integer i = 0; i < IB_WAY; i++) begin
				ibuf[i].valid <= 1'b0;
			end
		end else if(rii_st[2] == 1'b1) begin
			if(RII.r_est()) begin
				ibuf[miss_sel].data.w128[rii_st[1:0]] <= RII.RDATA;
			end
			if(RII.r_last()) begin
				ibuf[miss_sel].valid <= 1'b1;
				ibuf[miss_sel].tag   <= pc;
			end
		end
	end

	logic [31:0]		instr;

	always_comb begin
		hit = 1'b0;
		hit_sel = '0;
		for(integer i = 0; i < IB_WAY; i++) begin
			hit	= hit || is_hit(ibuf[i], pc);
			hit_sel	= is_hit(ibuf[i], pc) ? i[$clog2(IB_WAY)-1:0] : hit_sel;
		end

		miss = ~hit;
		miss_sel = $bits(miss_sel)'(hit_sel + 1'b1);

		instr = ibuf[hit_sel].data.w32[pc[5:2]];
	end

	wire [1:0] tmp = rii_st[1:0] + 'b1;
	always_ff @(posedge CLK or negedge RSTn) begin
		if(!RSTn) begin
			rii_st	<= '0;
		end else begin
			if(rii_st == '0) begin
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
		RII.ARVALID	= rii_st == '0 && miss;
		RII.ARADDR	= {pc[31:4], 4'h0};
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
			OVALID	<= hit && !IPC_WE;
			OPC	<= pc;
			OINSTR	<= instr;
		end
	end

endmodule
