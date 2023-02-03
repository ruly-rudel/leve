

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

qemu:
	qemu-system-riscv64 -M virt -nographic -kernel ../../linux/objdir/arch/riscv/boot/Image -append "console=ttyS0"

kernel:
	riscv64-unknown-linux-gnu-objdump -D ../../linux/objdir/vmlinux > vmlinux.dump

qemu-busybox:
	qemu-system-riscv64 -M virt -nographic -kernel ../../linux/objdir/arch/riscv/boot/Image -append "root=/dev/vda rw console=ttyS0" -drive file=../../root.bin,format=raw,id=hd0 -device virtio-blk-device,drive=hd0

clean:
	rm -rf obj_dir *.vcd *.log rv64ui-p.dump rv64ui-p vmlinux.dump
