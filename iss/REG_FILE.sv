`ifndef _reg_file_sv_
`define _reg_file_sv_

`include "defs.vh"

class REG_FILE;
	bit [`XLEN-1:0]		reg_file[0:`NUM_REG-1];

	function void write (input [4:0] addr, input [`XLEN-1:0] data);
		if(addr != 5'h00) reg_file[addr] = data;
	endfunction

	function void write32u (input [4:0] addr, input [32-1:0] data);
		if(addr != 5'h00) reg_file[addr] = {{32{1'b0}}, data};
	endfunction

	function void write32s (input [4:0] addr, input [32-1:0] data);
		if(addr != 5'h00) reg_file[addr] = {{32{data[31]}}, data};
	endfunction

	function void write16u (input [4:0] addr, input [16-1:0] data);
		reg_file[addr] = {{48{1'b0}}, data};
	endfunction

	function void write16s (input [4:0] addr, input [16-1:0] data);
		reg_file[addr] = {{48{data[15]}}, data};
	endfunction

	function void write8u (input [4:0] addr, input [8-1:0] data);
		reg_file[addr] = {{56{1'b0}}, data};
	endfunction

	function void write8s (input [4:0] addr, input [8-1:0] data);
		reg_file[addr] = {{56{data[7]}}, data};
	endfunction

	function [`XLEN-1:0] read (input [4:0] addr);
		return reg_file[addr];
	endfunction

	function [32-1:0] read32 (input [4:0] addr);
		return reg_file[addr][31:0];
	endfunction
endclass : REG_FILE;

`endif	// _reg_file_sv_
