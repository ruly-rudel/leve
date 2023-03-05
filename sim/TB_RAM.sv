
`include "defs.vh"
`include "ELF.sv"
`include "FRAG_MEMORY.sv"
`include "AXI.sv"

module TB_RAM
(
	input			CLK,
	input			RSTn,
	AXI.r_target		RT,
	input string		init_file
);

	FRAG_MEMORY		mem = new;
	ELF			elf;

	initial begin
		elf = new(init_file, mem);
	end

	assign RT.ARREADY = 1'b1;
	always_ff @(posedge CLK) begin
		if(RT.ARVALID && RT.ARREADY) begin
			RT.RDATA <= {mem.read64({{32{1'b0}}, RT.ARADDR[31:4] + 28'b1, 4'h0}), 
			             mem.read64({{32{1'b0}}, RT.ARADDR[31:4],       4'h0})};
			RT.RVALID <= 1'b1;
		end else begin
			RT.RVALID <= 1'b0;
		end
	end

endmodule

