`ifndef _reg_file_fp_sv_
`define _reg_file_fp_sv_

`include "defs.vh"

class REG_FILE_FP;
	logic [`FLEN-1:0]		reg_file[0:`FP_NUM_REG-1];

	function void write (input [4:0] addr, input [`XLEN-1:0] data);
		reg_file[addr] = data;
	endfunction

	function void write32u (input [4:0] addr, input [32-1:0] data);
		reg_file[addr] = {{32{1'b1}}, data};
	endfunction

	function [`XLEN-1:0] read (input [4:0] addr);
		return reg_file[addr];
	endfunction

	function [32-1:0] read32 (input [4:0] addr);
		return reg_file[addr][31:0];
	endfunction
endclass : REG_FILE_FP;

`endif	// _reg_file_fp_sv_
