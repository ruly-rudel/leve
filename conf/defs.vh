
`ifndef _defs_vh_
`define _defs_vh_

`define XLEN    64
`define FLEN    64
`define MXLEN   64
`define SXLEN   64
`define NUM_REG 32
`define FP_NUM_REG 32
`define NUM_CSR 4096

//`define PTE_V	4'h1
`define PTE_R	4'h2
`define PTE_W	4'h4
`define PTE_X	4'h8


`define	IRF_REG		3'h0
`define	IRF_IMM_I	3'h1
`define	IRF_IMM_S	3'h2
`define	IRF_IMM_B	3'h3
`define	IRF_IMM_U	3'h4
`define	IRF_IMM_W	3'h5
`define	IRF_SHAMT	3'h6
`define	IRF_ALU		3'h7

`define CSR_NONE	2'h0
`define CSR_WRITE	2'h1
`define CSR_SET		2'h2
`define CSR_CLEAR	2'h3

`define MODE_M	2'b11
`define MODE_S	2'b01
`define MODE_U	2'b00

`define MXL_32	2'h1
`define MXL_64	2'h2
`define MXL_128	2'h3

`define EX_IAMIS	4'h0
`define EX_IAFAULT	4'h1
`define EX_ILLEGINST	4'h2
`define EX_BREAK	4'h3
`define EX_LAMIS	4'h4
`define EX_LAFAULT	4'h5
`define EX_SAMIS	4'h6
`define EX_SAFAULT	4'h7
`define EX_ECALL_U	4'h8
`define EX_ECALL_S	4'h9
`define EX_ECALL_M	4'hb
`define EX_IPFAULT	4'hc
`define EX_LPFAULT	4'hd
`define EX_SPFAULT	4'hf


`define	TPD	#1

`endif // _defs_vh_
