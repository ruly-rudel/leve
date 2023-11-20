
`include "defs.vh"

interface INST(input [31:0] INSTR);

	function logic [6:0] opcode();
		return INSTR[6:0];
	endfunction

	function logic [2:0] funct3();
		return INSTR[14:12];
	endfunction

	function logic [1:0] funct3_1_0();
		return INSTR[13:12];
	endfunction

	function logic [6:0] funct7();
		return INSTR[31:25];
	endfunction

	function logic [4:0] rs1();
		return INSTR[19:15];
	endfunction

	function logic [4:0] rs2();
		return INSTR[24:20];
	endfunction

	function logic [4:0] rd0();
		return INSTR[11:7];
	endfunction

	function logic [11:0] csr();
		return INSTR[31:20];
	endfunction


	function logic mret();
		mret	= opcode() == 7'b11_100_11 && funct3() == 3'b000 && funct7() == 7'b0011000 && rs2() == 5'b00010;
	endfunction

endinterface

