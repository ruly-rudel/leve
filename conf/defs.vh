
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

`define	TPD	#1

`endif // _defs_vh_
