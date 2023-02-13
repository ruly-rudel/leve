`ifndef _flag_memory_sv_
`define _flag_memory_sv_

`include "defs.vh"


class FLAG_MEMORY_ITEM;
	bit				en;
	bit [63:0]			start;
	bit [31:0]			size;
	bit [24+6-1:0]		offset;

	function new();
		en = 1'b0;
	endfunction

	function bit get_en();
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

	function void set_en(bit e);
		en = e;
	endfunction

	function void set_start(bit [63:0] stat);
		start = stat;
	endfunction

	function void set_size(bit [31:0] siz);
		size = siz;
	endfunction

	function void set_offset(bit [24+6-1:0] ofs);
		offset = ofs;
	endfunction
endclass : FLAG_MEMORY_ITEM;

//`define FLAG_MEM_NUM_POW	2
//`define FLAG_MEM_SIZE_POW	24
`define FLAG_MEM_NUM_POW	8
`define FLAG_MEM_SIZE_POW	12
`define FLAG_MEM_NUM	(1<<`FLAG_MEM_NUM_POW)

class FRAG_MEMORY;
	FLAG_MEMORY_ITEM		mems[int];
	bit [31:0]			mem[]  = new [`FLAG_MEM_NUM*(1<<(`FLAG_MEM_SIZE_POW-2))];

	function new();
		for(int i = 0; i < `FLAG_MEM_NUM; i = i + 1) begin
			mems[i] = new;
			mems[i].set_en(1'b0);
		end
	endfunction

	function int get_idx_or_alloc(bit [63:0] addr);
		int idx = find_idx(addr);
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

	function int get_last_idx();
		for(int i = 0; i < `FLAG_MEM_NUM; i = i + 1) begin
			if(mems[i].get_en() == 1'b0) return i;
		end
		return -1;
	endfunction

	function int find_idx(bit [63:0] addr);
		for(int i = 0; i < `FLAG_MEM_NUM; i = i + 1) begin
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

	function [31:0] read_idx(int idx, bit [63:0] addr);
		bit [63:0] tmp = addr - mems[idx].get_start() + {{34{1'b0}}, mems[idx].get_offset()};
		return mem[tmp[`FLAG_MEM_SIZE_POW+`FLAG_MEM_NUM_POW-1:2]];
	endfunction

	function void write_idx(int idx, bit [63:0] addr, bit [31:0] data);
		bit [63:0] tmp = addr - mems[idx].get_start() + {{34{1'b0}}, mems[idx].get_offset()};
		mem[tmp[`FLAG_MEM_SIZE_POW+`FLAG_MEM_NUM_POW-1:2]] = data;
	endfunction

	function [31:0] read(bit [63:0] addr);
		int idx = find_idx(addr);
		if(idx == -1) begin
			return 32'h0;
		end else begin
			return read_idx(idx, addr);
		end
	endfunction

	function void write(bit [63:0] addr, bit [31:0] data);
		int idx = get_idx_or_alloc(addr);
		if(idx != -1) begin
			write_idx(idx, addr, data);
		end
	endfunction

endclass : FRAG_MEMORY;

`endif	// _flag_memory_sv_
