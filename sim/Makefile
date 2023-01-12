

sc:
	verilator --sc --exe --build -I../conf -I../iss sc_main.cpp tb_iss.sv ../iss/RISCV64G_ISS.sv

sc-trace:
	verilator --sc --trace --exe --build -I../conf -I../iss sc_main.cpp tb_iss.sv ../iss/RISCV64G_ISS.sv

test:
	./run.sh

cc:
	verilator --cc --exe --build -Wall sim_main.cpp ../iss/RISCV64G_ISS.sv


clean:
	rm -rf obj_dir *.vcd *.log
