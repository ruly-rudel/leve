
`include "defs.vh"
`include "ELF.sv"
`include "FRAG_MEMORY.sv"
`include "AXI.sv"

module TB_RAM
(
	input			CLK,
	input			RSTn,
	AXI.r_target		RT,
	AXI.w_target		WT,
	input string		init_file
);

	FRAG_MEMORY		mem = new;
	ELF			elf;

	logic			r_st;
	logic [7:0]		r_cnt;
	logic [31:0]		r_addr;

	logic [1:0]		w_st;
	logic [7:0]		w_cnt;
	logic [31:0]		w_addr;

	// memory data initialization from elf file
	initial begin
		elf = new(init_file, mem);
	end

	//////////////////////////////////////////////////////////////////////////////
	// READ
	// state machine
	always_ff @(posedge CLK or negedge RSTn) begin
		if(!RSTn) begin
					r_st <= 1'h0;
		end else begin
			case(r_st)
			1'b0: begin
				if(RT.ARVALID && RT.ARREADY) begin
					r_st <= `TPD 1'b1;
				end
			end
			1'b1: begin
				if(r_cnt == 8'h00) begin
					r_st <= `TPD 1'b0;
				end
			end
			endcase
		end
	end

	// burst read counter
	always_ff @(posedge CLK or negedge RSTn) begin
		if(!RSTn) begin
					r_cnt  <= 8'h0;
					r_addr <= 32'h0000_0000;
		end else begin
			case(r_st)
			1'b0: begin
				if(RT.ARVALID && RT.ARREADY) begin
					r_cnt  <= `TPD RT.ARLEN;
					r_addr <= `TPD RT.ARADDR;
				end
			end
			1'b1: begin
				if(RT.RVALID && RT.RREADY) begin
					r_cnt  <= `TPD r_cnt - 'b1;
					r_addr <= `TPD r_addr + 'h10;
				end
			end
			endcase
		end
	end

	// ARREADY = 1 when read state is idle.
	assign RT.ARREADY = r_st == 1'b0 ? 1'b1 : 1'b0;

	// RVALID = 1 when read state is read.
	assign RT.RVALID  = r_st == 1'b1 ? 1'b1 : 1'b0;

	assign RT.RLAST   = r_st == 1'b1 && r_cnt == 8'h00 ? 1'b1 : 1'b0;

	always_comb begin
		mem.read128({{32{1'b0}}, r_addr}, RT.RDATA);
	end

	//////////////////////////////////////////////////////////////////////////////
	// WRITE
	// state machine
	always_ff @(posedge CLK or negedge RSTn) begin
		if(!RSTn) begin
					w_st <= 2'h0;
		end else begin
			case(w_st)
			2'h0: begin
				if(WT.AWVALID && WT.AWREADY) begin
					w_st <= `TPD 2'h1;
				end
			end
			2'h1: begin
				if(w_cnt == 8'h00) begin
					w_st <= `TPD 2'h2;
				end
			end
			2'h2: begin
				if(WT.BVALID && WT.BREADY) begin
					w_st <= `TPD 2'h0;
				end
			end
			default: ;
			endcase
		end
	end

	// burst write counter
	always_ff @(posedge CLK or negedge RSTn) begin
		if(!RSTn) begin
					w_cnt  <= 8'h0;
					w_addr <= 32'h0000_0000;
		end else begin
			case(w_st)
			2'b0: begin
				if(WT.AWVALID && WT.AWREADY) begin
					w_cnt  <= `TPD WT.AWLEN;
					w_addr <= `TPD WT.AWADDR;
				end
			end
			2'b1: begin
				if(WT.WVALID && WT.WREADY) begin
					w_cnt  <= `TPD w_cnt - 'b1;
					w_addr <= `TPD w_addr + 'h10;
				end
			end
			default: ;
			endcase
		end
	end

	// AWREADY = 1 when write state is idle.
	assign WT.AWREADY = w_st == 2'h0 ? 1'b1 : 1'b0;

	// WREADY = 1 when write state is write.
	assign WT.WREADY  = w_st == 2'h1 ? 1'b1 : 1'b0;

	// BVALID = 1 when write state is resp.
	assign WT.BVALID  = w_st == 2'h2 ? 1'b1 : 1'b0;
	assign WT.BRESP   = `AXI_RESP_OKAY;


	always_ff @(posedge CLK or negedge RSTn) begin
		logic [127:0]	rdata;
		logic [127:0]	wdata;
		logic [127:0]	mask;
		if(RSTn) begin
			if(w_st == 2'h1 && WT.WVALID && WT.WREADY) begin
				mem.read128({{32{1'b0}}, w_addr}, rdata);
				mask = {
					{8{WT.WSTRB[15]}},
					{8{WT.WSTRB[14]}},
					{8{WT.WSTRB[13]}},
					{8{WT.WSTRB[12]}},
					{8{WT.WSTRB[11]}},
					{8{WT.WSTRB[10]}},
					{8{WT.WSTRB[9]}},
					{8{WT.WSTRB[8]}},
					{8{WT.WSTRB[7]}},
					{8{WT.WSTRB[6]}},
					{8{WT.WSTRB[5]}},
					{8{WT.WSTRB[4]}},
					{8{WT.WSTRB[3]}},
					{8{WT.WSTRB[2]}},
					{8{WT.WSTRB[1]}},
					{8{WT.WSTRB[0]}}
				       };
				wdata = WT.WDATA & mask | rdata & ~mask;
				mem.write128({{32{1'b0}}, w_addr}, wdata);
			end
		end
	end

endmodule

