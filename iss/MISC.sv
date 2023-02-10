`ifndef _misc_sv_
`define _misc_sv_

`include "defs.vh"

function [`XLEN-1:0]	twoscompXLEN(input sign, input [`XLEN-1:0] i);
	if(sign) begin
		twoscompXLEN = ~i + 'b1;
	end else begin
		twoscompXLEN = i;
	end
endfunction

function [`XLEN/2-1:0]	twoscompXLENh(input sign, input [`XLEN/2-1:0] i);
	if(sign) begin
		twoscompXLENh = ~i + 'b1;
	end else begin
		twoscompXLENh = i;
	end
endfunction

function [`XLEN*2-1:0]	twoscompXLENx2(input sign, input [`XLEN*2-1:0] i);
	if(sign) begin
		twoscompXLENx2 = ~i + 'b1;
	end else begin
		twoscompXLENx2 = i;
	end
endfunction

function [`XLEN-1:0]	absXLEN(input [`XLEN-1:0] i);
	absXLEN = twoscompXLEN(i[`XLEN-1], i);
endfunction

function [`XLEN/2-1:0]	absXLENh(input [`XLEN/2-1:0] i);
	absXLENh = twoscompXLENh(i[`XLEN/2-1], i);
endfunction

`endif	// _misc_sv_
