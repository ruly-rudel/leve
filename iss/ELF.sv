`ifndef _elf_sv_
`define _elf_sv_

`include "defs.vh"

`include "FRAG_MEMORY.sv"

class ELF;
	string				filename;
	FRAG_MEMORY			mem;
	bit [63:0]			tohost;

	// elf header
	bit [7:0]			e_ident[0:15];
	bit [15:0]			e_type;
	bit [15:0]			e_machine;
	bit [31:0]			e_version;
	bit [63:0]			e_entry;
	bit [63:0]			e_phoff;
	bit [63:0]			e_shoff;
	bit [31:0]			e_flags;
	bit [15:0]			e_ehsize;
	bit [15:0]			e_phentsize;
	bit [15:0]			e_phnum;
	bit [15:0]			e_shentsize;
	bit [15:0]			e_shnum;
	bit [15:0]			e_shstrndx;

	// program header
	struct packed {
		bit [31:0]		p_type;
		bit [31:0]		p_flags;
		bit [63:0]		p_offset;
		bit [63:0]		p_vaddr;
		bit [63:0]		p_paddr;
		bit [63:0]		p_filesz;
		bit [63:0]		p_memsz;
		bit [63:0]		p_align;
	} phdr[];

	// section header
	struct packed {
		bit [31:0]		sh_name;
		bit [31:0]		sh_type;
		bit [63:0]		sh_flags;
		bit [63:0]		sh_addr;
		bit [63:0]		sh_offset;
		bit [63:0]		sh_size;
		bit [31:0]		sh_link;
		bit [31:0]		sh_info;
		bit [63:0]		sh_addralign;
		bit [63:0]		sh_entsize;
	} shdr[];

	function new(string fn, FRAG_MEMORY fm);
		integer fd;

		mem = fm;
		filename = fn;
		$display("[ELF] read %s", filename);
		fd = $fopen(filename, "r");
		if(fd == 0) begin
			$display("[ELF] file open fails: %s", filename);
			$finish;
		end

		read_elf_header(fd);
		read_program_header(fd);
		load(fd);
		read_section_header(fd);
		print_section_name(fd);
		set_tohost(fd);

		$fclose(fd);
		$display("[ELF] read finish.");

	endfunction

	function void load(input integer fd);
		integer ret;
		bit [63:0]	addr;

		for(integer i = 0; i < e_phnum; i = i + 1) begin
			ret = $fseek(fd, phdr[i].p_offset[31:0], 0);
			for(integer j = 0; j < phdr[i].p_filesz[31:0]; j = j + 4) begin
				addr = phdr[i].p_vaddr + {32'h0000_0000, j};
				mem.write(addr, read_w(fd));
//				$display("%16h: %08h", addr, mem[addr[24-1:2]]);
			end
		end
	endfunction

	function void print_section_name(input integer fd);
		string s;
		for(integer i = 0; i < e_shnum; i = i + 1) begin
			s = get_string(fd, shdr[i].sh_name);
			$display("[SECTION %02d].sh_name: %s", i, s);

			case(shdr[i].sh_type)
				32'h0: $display("shdr[%2d].sh_type: SHT_NULL(%2d)", i, shdr[i].sh_type);
				32'h1: $display("shdr[%2d].sh_type: SHT_PROGBITS(%2d)", i, shdr[i].sh_type);
				32'h2: $display("shdr[%2d].sh_type: SHT_SYMTAB(%2d)", i, shdr[i].sh_type);
				32'h3: $display("shdr[%2d].sh_type: SHT_STRTAB(%2d)", i, shdr[i].sh_type);
				32'h4: $display("shdr[%2d].sh_type: SHT_RELA(%2d)", i, shdr[i].sh_type);
				32'h5: $display("shdr[%2d].sh_type: SHT_HASH(%2d)", i, shdr[i].sh_type);
				32'h6: $display("shdr[%2d].sh_type: SHT_DYNAMIC(%2d)", i, shdr[i].sh_type);
				32'h7: $display("shdr[%2d].sh_type: SHT_NOTE(%2d)", i, shdr[i].sh_type);
				32'h8: $display("shdr[%2d].sh_type: SHT_NOBITS(%2d)", i, shdr[i].sh_type);
				32'h9: $display("shdr[%2d].sh_type: SHT_REL(%2d)", i, shdr[i].sh_type);
				32'h10: $display("shdr[%2d].sh_type: SHT_SHLIB(%2d)", i, shdr[i].sh_type);
				32'h11: $display("shdr[%2d].sh_type: SHT_DYNSYM(%2d)", i, shdr[i].sh_type);
				32'h12: $display("shdr[%2d].sh_type: SHT_NUM(%2d)", i, shdr[i].sh_type);
				default: $display("shdr[%2d].sh_type: ??? (%2d)", i, shdr[i].sh_type);
			endcase
			$display("shdr[%2d].sh_addr: %2h", i, shdr[i].sh_addr);
			$display("shdr[%2d].sh_offset: %2d", i, shdr[i].sh_offset);
			$display("shdr[%2d].sh_size: %2d", i, shdr[i].sh_size);
		end
	endfunction

	function void read_section_header(input integer fd);
		integer ret;
		shdr = new [{16'h0000, e_shnum}];
		ret = $fseek(fd, e_shoff[31:0], 0);

		for(integer i = 0; i < e_shnum; i = i + 1) begin
			shdr[i].sh_name		= read_w(fd);
			shdr[i].sh_type		= read_w(fd);
			shdr[i].sh_flags	= read_dw(fd);
			shdr[i].sh_addr		= read_dw(fd);
			shdr[i].sh_offset	= read_dw(fd);
			shdr[i].sh_size		= read_dw(fd);
			shdr[i].sh_link		= read_w(fd);
			shdr[i].sh_info		= read_w(fd);
			shdr[i].sh_addralign	= read_dw(fd);
			shdr[i].sh_entsize	= read_dw(fd);
		end
	endfunction

	function string get_string(input integer fd, input integer offset);
		integer ret;
		bit [7:0] ch;
		string	rs = "";
		integer addr = shdr[e_shstrndx].sh_offset[31:0] + offset;
		ret = $fseek(fd, addr, 0);

		ch = read_c(fd);
		while(ch != 8'h00) begin
			rs = {rs, ch};
			ch = read_c(fd);
		end

		return rs;

	endfunction

	function void read_program_header(input integer fd);
		integer ret;
		phdr = new [{16'h0000, e_phnum}];
		ret = $fseek(fd, e_phoff[31:0], 0);

		for(integer i = 0; i < e_phnum; i = i + 1) begin
			phdr[i].p_type		= read_w(fd);
			phdr[i].p_flags		= read_w(fd);
			phdr[i].p_offset	= read_dw(fd);
			phdr[i].p_vaddr		= read_dw(fd);
			phdr[i].p_paddr		= read_dw(fd);
			phdr[i].p_filesz	= read_dw(fd);
			phdr[i].p_memsz		= read_dw(fd);
			phdr[i].p_align		= read_dw(fd);


			if(phdr[i].p_type == 32'h1) begin
				$display("phdr[%2d].p_type: PT_LOAD(1)", i);
			end else begin
				$display("phdr[%2d].p_type: %2d", i, phdr[i].p_type);
			end
			$display("phdr[%2d].p_offset: %2d", i, phdr[i].p_offset);
			$display("phdr[%2d].p_vaddr:  %h", i, phdr[i].p_vaddr);
			$display("phdr[%2d].p_paddr:  %h", i, phdr[i].p_paddr);
			$display("phdr[%2d].p_filesz: %2d", i, phdr[i].p_filesz);
			$display("phdr[%2d].p_memsz:  %2d", i, phdr[i].p_memsz);
			$display("phdr[%2d].p_align:  %2d", i, phdr[i].p_align);
		end
	endfunction

	function void read_elf_header(input integer fd);
		integer ret;

		// ELF Header
		ret = $fread(e_ident, fd);
		if(ret != 16) begin
			$display("[MEMORY] file read fails: %s, %d", filename, ret);
		end
		e_type		= read_hw(fd);
		e_machine	= read_hw(fd);
		e_version	= read_w(fd);
		e_entry		= read_dw(fd);
		e_phoff		= read_dw(fd);
		e_shoff		= read_dw(fd);
		e_flags		= read_w(fd);
		e_ehsize	= read_hw(fd);
		e_phentsize	= read_hw(fd);
		e_phnum		= read_hw(fd);
		e_shentsize	= read_hw(fd);
		e_shnum		= read_hw(fd);
		e_shstrndx	= read_hw(fd);


		if(
			e_ident[0] == 8'h7f &&		// 0x7f
			e_ident[1] == 8'h45 &&		// E
			e_ident[2] == 8'h4C &&		// L
			e_ident[3] == 8'h46		// F
		) begin
			$display("ELF ID found: %02h %c%c%c", e_ident[0], e_ident[1], e_ident[2], e_ident[3]);
		end

		if(e_ident[4] == 8'h01) begin
			$display("ELFCLASS32");
		end else if (e_ident[4] == 8'h02) begin
			$display("ELFCLASS64");
		end

		if(e_ident[5] == 8'h01) begin
			$display("ELFDATA2LSB");
		end else if (e_ident[4] == 8'h02) begin
			$display("ELFDATA2MSB");
		end


		if(e_type == 16'h0001) begin
			$display("ET_REL");
		end else if (e_type == 16'h0002) begin
			$display("ET_EXEC");
		end else if (e_type == 16'h0003) begin
			$display("ET_DYN");
		end else if (e_type == 16'h0004) begin
			$display("ET_CORE");
		end

		$display("e_machine: %04h", e_machine);
		$display("e_version: %h", e_version);
		$display("Entry Point: %016h", e_entry);
		$display("Program Header Table Offset: %d (bytes into file)", e_phoff);
		$display("Section Header Table Offset: %d (bytes into file)", e_shoff);
		$display("e_flags: %h", e_flags);
		$display("Elf Header Size: %d", e_ehsize);
		$display("Program Headers Size: %d", e_phentsize);
		$display("Number of Program Header: %d", e_phnum);
		$display("Section Headers Size: %d", e_shentsize);
		$display("Number of Section Header: %d", e_shnum);

		$display("String table index: %d", e_shstrndx);
	endfunction

	function [7:0] read_c(integer fd);
		integer ret;
		bit [7:0] r_c;

		ret = $fread(r_c, fd);
		if(ret != 1) begin
			$display("[MEMORY] file read fails, hw: %s, %d", filename, ret);
		end
		return r_c;
	endfunction

	function [15:0] read_hw(integer fd);
		integer ret;
		bit [7:0] r_hw[0:1];

		ret = $fread(r_hw, fd);
		if(ret != 2) begin
			$display("[MEMORY] file read fails, hw: %s, %d", filename, ret);
		end
		return {r_hw[1], r_hw[0]};
	endfunction

	function [31:0] read_w(integer fd);
		integer ret;
		bit [7:0] r_w[0:3];

		ret = $fread(r_w, fd);
		if(ret != 4) begin
			$display("[MEMORY] file read fails,  w: %s, %d", filename, ret);
		end
		return {r_w[3], r_w[2], r_w[1], r_w[0]};
	endfunction

	function [63:0] read_dw(integer fd);
		integer ret;
		bit [7:0] r_dw[0:7];

		ret = $fread(r_dw, fd);
		if(ret != 8) begin
			$display("[MEMORY] file read fails, dw: %s, %d", filename, ret);
		end
		return {r_dw[7], r_dw[6], r_dw[5], r_dw[4], r_dw[3], r_dw[2], r_dw[1], r_dw[0]};
	endfunction




	function [63:0] get_entry_point();
		return e_entry;
	endfunction

	function void set_tohost(input integer fd);
		for(integer i = 0; i < e_shnum; i = i + 1) begin
			string s = get_string(fd, shdr[i].sh_name);
			if(s == ".tohost") begin
				$display("[ELF] .tohost found at shdr[%2d], address %02h", i, shdr[i].sh_addr);
				tohost = shdr[i].sh_addr;
				return ;
			end
		end

		$display("[ELF] .tohost does not found.");
		tohost = {`XLEN{1'b0}};
		return;
	endfunction

	function [63:0] get_tohost();
		return tohost;
	endfunction

endclass : ELF;

`endif	// _elf_sv_
