#!/bin/bash

if [ $# -eq 0 ]; then
	#files=(`ls -1 ../../riscv-tests/isa/rv64ui-p-* ../../riscv-tests/isa/rv64um-p-* ../../riscv-tests/isa/rv64ua-p-* ../../riscv-tests/isa/rv64uf-p-* ../../riscv-tests/isa/rv64ud-p-* ../../riscv-tests/isa/rv64uc-p-* ../../riscv-tests/isa/rv64si-p-* ../../riscv-tests/isa/rv64ui-v-* | grep -v .dump`)
	files=(`ls -1 ../../riscv-tests/isa/rv64ui-p-* ../../riscv-tests/isa/rv64um-p-* ../../riscv-tests/isa/rv64ua-p-* ../../riscv-tests/isa/rv64uf-p-* ../../riscv-tests/isa/rv64ud-p-* ../../riscv-tests/isa/rv64uc-p-* ../../riscv-tests/isa/rv64si-p-* | grep -v .dump`)

else
	files=$@
fi

rm iss.log
for file_name in "${files[@]}"; do
	echo "[TESTBENCH] execute test ${file_name}" >> iss.log
	./obj_dir/Vtb_iss +ELF=${file_name} >> iss.log
done
