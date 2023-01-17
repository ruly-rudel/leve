

sc:
	verilator --sc --exe --build -I../conf -I../iss sc_main.cpp tb_iss.sv ../iss/RISCV64G_ISS.sv ../iss/FMUL_F.sv

sc-trace:
	verilator --sc --trace --exe --build -I../conf -I../iss sc_main.cpp tb_iss.sv ../iss/RISCV64G_ISS.sv ../iss/FMUL_F.sv

test:
	./run.sh

sc-fp:
	verilator --sc --trace --exe --build -I../conf -I../iss fp_sc_main.cpp ../iss/FMUL_F.sv


clean:
	rm -rf obj_dir *.vcd *.log rv64ui-p.dump rv64ui-p.hex
