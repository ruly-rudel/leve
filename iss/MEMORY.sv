`ifndef _memory_sv_
`define _memory_sv_

`include "defs.vh"

class MEMORY;
	logic [32-1:0]			mem[] = new [1024*1024*4];

	function new(string filename);
		integer fd;
		integer ret;
		integer i = 0;
		string str;
		$display("[MEMORY] read %s", filename);
		fd = $fopen(filename, "r");
		if(fd == 0) begin
			$display("[MEMORY] file open fails: %s", filename);
			$finish;
		end

		while (!$feof(fd)) begin
			ret = $fgets(str, fd);
			if(ret == 0) begin
				$display("[MEMORY] file read fails: %s, line %d", filename, i);
			end else begin
				mem[i++] = str.atohex();
			end
		end

		$fclose(fd);
		$display("[MEMORY] read finish.");

	endfunction

	function void write (input [`XLEN-1:0] addr, input [`XLEN-1:0] data);
		mem[addr[24-1:2]] = data[31:0];
		mem[addr[24-1:2] + 22'h1] = data[63:32];
	endfunction

	function void write32 (input [`XLEN-1:0] addr, input [32-1:0] data);
		mem[addr[24-1:2]] = data;
	endfunction

	function void write16 (input [`XLEN-1:0] addr, input [16-1:0] data);
		logic [31:0]	tmp32;
		tmp32 = mem[addr[22-1:2]];
		case (addr[1])
			1'b0 : mem[addr[24-1:2]] = {tmp32[31:16], data};
			1'b1 : mem[addr[24-1:2]] = {data[15:0], tmp32[15:0]};
		endcase
	endfunction

	function void write8 (input [`XLEN-1:0] addr, input [8-1:0] data);
		logic [31:0]	tmp32;
		tmp32 = mem[addr[24-1:2]];
		case (addr[1:0])
			2'h0 : mem[addr[24-1:2]] = {tmp32[31:8], data};
			2'h1 : mem[addr[24-1:2]] = {tmp32[31:16], data, tmp32[7:0]};
			2'h2 : mem[addr[24-1:2]] = {tmp32[31:24], data, tmp32[15:0]};
			2'h3 : mem[addr[24-1:2]] = {data, tmp32[23:0]};
		endcase
	endfunction

	function [`XLEN-1:0] read (input [`XLEN-1:0] addr);
		return {mem[addr[24-1:2] + 22'h1], mem[addr[22-1:2]]};
	endfunction

	function [32-1:0] read32 (input [`XLEN-1:0] addr);
		return mem[addr[24-1:2]];
	endfunction

	function [16-1:0] read16 (input [`XLEN-1:0] addr);
		case(addr[1])
			1'h0 : return mem[addr[24-1:2]][15:0];
			1'h1 : return mem[addr[24-1:2]][31:16];
		endcase
	endfunction

	function [8-1:0] read8 (input [`XLEN-1:0] addr);
		case(addr[1:0])
			2'h0 : return mem[addr[24-1:2]][7:0];
			2'h1 : return mem[addr[24-1:2]][15:8];
			2'h2 : return mem[addr[24-1:2]][23:16];
			2'h3 : return mem[addr[24-1:2]][31:24];
		endcase
	endfunction

endclass : MEMORY;

`endif	// _memory_sv_
