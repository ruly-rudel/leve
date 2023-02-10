`ifndef _flag_memory_sv_
`define _flag_memory_sv_

`include "defs.vh"


class FLAG_MEMORY_ITEM;
	logic				en;
	logic [63:0]			start;
	logic [31:0]			size;
	logic [24+6-1:0]		offset;

	function new();
		en = 1'b0;
	endfunction

	function logic get_en();
		return en;
	endfunction

	function [63:0] get_start();
		return start;
	endfunction

	function [31:0] get_size();
		return size;
	endfunction

	function [24+6-1:0] get_offset();
		return offset;
	endfunction

	function void set_en(logic e);
		en = e;
	endfunction

	function void set_start(logic [63:0] stat);
		start = stat;
	endfunction

	function void set_size(logic [31:0] siz);
		size = siz;
	endfunction

	function void set_offset(logic [24+6-1:0] ofs);
		offset = ofs;
	endfunction
endclass : FLAG_MEMORY_ITEM;

`define FLAG_MEM_SIZE	4
`define FLAG_MEM_SIZE_POW	2

class FRAG_MEMORY;
	FLAG_MEMORY_ITEM		mems[integer];
	logic [31:0]			mem[]  = new [`FLAG_MEM_SIZE*1024*1024*4];

	function new();
		for(integer i = 0; i < `FLAG_MEM_SIZE; i = i + 1) begin
			mems[i] = new;
			mems[i].set_en(1'b0);
		end
	endfunction

	function integer get_idx_or_alloc(logic [63:0] addr);
		integer idx = find_idx(addr);
		if(idx >= 0) return idx;

		idx = get_last_idx();
		if(idx != -1) begin
			$display("[MEMORY] allocate addr %16h.", addr);
			mems[idx].set_en(1'b1);
			mems[idx].set_start({addr[63:24], 24'h00_0000});
			mems[idx].set_size(1024*1024*4*4);
			mems[idx].set_offset({idx[5:0], 24'h00_0000});
		end

		return idx;
	endfunction

	function integer get_last_idx();
		for(integer i = 0; i < `FLAG_MEM_SIZE; i = i + 1) begin
			if(mems[i].get_en() == 1'b0) return i;
		end
		return -1;
	endfunction

	function integer find_idx(logic [63:0] addr);
		for(integer i = 0; i < `FLAG_MEM_SIZE; i = i + 1) begin
			if(mems[i].get_en()) begin
				if(addr >= mems[i].get_start()) begin
					if(addr < mems[i].get_start() + {{32{1'b0}}, mems[i].get_size()}) begin
						return i;
					end
				end
			end
		end
		return -1;
	endfunction

	function [31:0] read_idx(integer idx, logic [63:0] addr);
		logic [63:0] tmp = addr - mems[idx].get_start() + {{34{1'b0}}, mems[idx].get_offset()};
		return mem[tmp[24+`FLAG_MEM_SIZE_POW-1:2]];
	endfunction

	function void write_idx(integer idx, logic [63:0] addr, logic [31:0] data);
		logic [63:0] tmp = addr - mems[idx].get_start() + {{34{1'b0}}, mems[idx].get_offset()};
		mem[tmp[24+`FLAG_MEM_SIZE_POW-1:2]] = data;
	endfunction

	function [31:0] read(logic [63:0] addr);
		integer idx = find_idx(addr);
		if(idx == -1) begin
			return 32'h0;
		end else begin
			return read_idx(idx, addr);
		end
	endfunction

	function void write(logic [63:0] addr, logic [31:0] data);
		integer idx = get_idx_or_alloc(addr);
		if(idx != -1) begin
			write_idx(idx, addr, data);
		end
	endfunction

endclass : FRAG_MEMORY;

`endif	// _flag_memory_sv_
