
ISS_SRC = sc_main.cpp tb_iss.sv $(wildcard ../iss/*.sv) ../conf/defs.vh
RTL_SRC = sc_rtl_main.cpp tb_rtl.sv $(wildcard ../iss/*.sv) $(wildcard ../rtl/*.sv) TB_RAM.sv ../conf/defs.vh

lint:	$(wildcard ../rtl/*.sv)
	verilator --lint-only --Wall --timing -I../conf -I../rtl ../rtl/LEVE1.sv

obj_dir/Vtb_rtl:	$(RTL_SRC)
	verilator --sc --trace --timing --exe --build -I../conf -I../iss -I../rtl sc_rtl_main.cpp tb_rtl.sv ../rtl/LEVE1.sv

obj_dir/Vtb_iss:	$(ISS_SRC)
	verilator --sc --exe --build -I../conf -I../iss sc_main.cpp tb_iss.sv ../iss/RV64GC_ISS.sv

sc-trace:	$(ISS_SRC)
	verilator --sc --trace --exe --build -I../conf -I../iss sc_main.cpp tb_iss.sv ../iss/RV64GC_ISS.sv

iss-test:	obj_dir/Vtb_iss
	./run.sh

rtl-test:	obj_dir/Vtb_rtl
	obj_dir/Vtb_rtl +ELF=../../riscv-tests/isa/rv64ui-p-add

sc-fmulf:
	verilator --sc --trace --exe --build -I../conf -I../iss fmul_f_sc_main.cpp ../iss/FMUL_F.sv

sc-faddf:
	verilator --sc --trace --exe --build -I../conf -I../iss fadd_f_sc_main.cpp ../iss/FADD_F.sv

qemu:
	qemu-system-riscv64 -M virt -nographic -kernel ../../linux/objdir/arch/riscv/boot/Image -append "console=ttyS0"

kernel:
	riscv64-unknown-linux-gnu-objdump -D ../../linux/objdir/vmlinux > vmlinux.dump

qemu-busybox:
	qemu-system-riscv64 -M virt -nographic -kernel ../../linux/objdir/arch/riscv/boot/Image -append "root=/dev/vda rw console=ttyS0" -drive file=../../root.bin,format=raw,id=hd0 -device virtio-blk-device,drive=hd0

clean:
	rm -rf obj_dir *.vcd *.log
