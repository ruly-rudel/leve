
`include "defs.vh"
`include "AXI.sv"
`include "PC.sv"
`include "HS.sv"

module LEVE_IBB
(
	input logic			CLK,
	input logic			RSTn,

	AXIR.init			RII,
	PC.target			PC,
	HS.init				INST
);
	logic	[1:0]		st;
	logic	[31:0]		pc_aligned;
	logic	[31:0]		burst_addr;
	logic			burst_addr_v;
	logic			burst_hit;
	logic	[1:0]		burst_cnt;
	logic	[127:0]		burst_buff [0:3];
	logic			burst_buff_v [0:3];
	logic	[127:0]		burst_buff_sel;


	always_comb begin
		pc_aligned	= {PC.PC[31:6], 6'h00};
		burst_hit	= burst_addr == pc_aligned && burst_addr_v ? 1'b1 : 1'b0;

		RII.ARVALID	= st == 2'h1 ? 1'b1 : 1'b0;
		PC.READY	= st == 2'h0 && burst_hit ? 1'b1 : 1'b0;
		RII.ARADDR	= burst_addr;
		RII.ARBURST	= `AXI_BURST_WRAP;
		RII.ARLEN	= 8'd3;

		RII.RREADY	= 1'b1;

		burst_buff_sel	= burst_buff[PC.PC[5:4]];
		case(PC.PC[3:2])
			2'h0:	INST.PAYLOAD = burst_buff_sel[31:0];
			2'h1:	INST.PAYLOAD = burst_buff_sel[63:32];
			2'h2:	INST.PAYLOAD = burst_buff_sel[95:64];
			2'h3:	INST.PAYLOAD = burst_buff_sel[127:96];
		endcase
		INST.VALID	= st == 2'h0 && burst_hit ? 1'b1 : 1'b0;

	end

	always_ff @(posedge CLK or negedge RSTn) begin
		if(!RSTn) begin
			st		= 2'h0;
			burst_addr_v	= 1'b0;
			burst_cnt	= 2'h0;
		end else begin
			case(st)
				2'h0: begin
					if(PC.VALID && !burst_hit) begin
						burst_addr	<= `TPD pc_aligned;
						burst_addr_v	<= `TPD 1'b1;
						for(int i = 0; i < 4; i = i + 1) begin
							burst_buff_v[i]	<= `TPD 1'b0;
						end
						st		<= `TPD 2'h1;
					end
				end
				2'h1: begin
					if(RII.ar_est()) begin
						burst_cnt	<= `TPD 2'h0;
						st		<= `TPD 2'h2;
					end
				end
				2'h2: begin
					if(RII.r_est()) begin
						burst_buff[burst_cnt]	<= `TPD RII.RDATA;
						burst_buff_v[burst_cnt]	<= `TPD 1'b1;
						burst_cnt	<= `TPD burst_cnt + 'b1;
						if(RII.RLAST) begin
							st	<= `TPD 2'h0;
						end
					end
				end
				default: ;
			endcase
		end
	end

/*
	always @(posedge CLK) begin
		if(RII.r_est()) begin
			$display("[INFO] RDATA = %h", RII.RDATA);
		end
	end
*/

endmodule : LEVE_IBB
