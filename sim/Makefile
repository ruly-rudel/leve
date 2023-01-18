

sc-trace:
	verilator --sc --trace --exe --build -I../conf -I../iss sc_main.cpp tb_iss.sv ../iss/RISCV64G_ISS.sv

sc:
	verilator --sc --exe --build -I../conf -I../iss sc_main.cpp tb_iss.sv ../iss/RISCV64G_ISS.sv

test:
	./run.sh

sc-fmulf:
	verilator --sc --trace --exe --build -I../conf -I../iss fmul_f_sc_main.cpp ../iss/FMUL_F.sv

sc-faddf:
	verilator --sc --trace --exe --build -I../conf -I../iss fadd_f_sc_main.cpp ../iss/FADD_F.sv


clean:
	rm -rf obj_dir *.vcd *.log rv64ui-p.dump rv64ui-p.hex
