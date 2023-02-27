#!/bin/bash

if [ $# -eq 0 ]; then
	files=(`ls -1 ../../riscv-tests/isa/rv64ui-* ../../riscv-tests/isa/rv64um-* ../../riscv-tests/isa/rv64ua-* ../../riscv-tests/isa/rv64uf-* ../../riscv-tests/isa/rv64ud-* ../../riscv-tests/isa/rv64uc-* ../../riscv-tests/isa/rv64si-* | grep -v .dump`)
	#files=(`ls -1 ../../riscv-tests/isa/rv64ui-* ../../riscv-tests/isa/rv64um-* ../../riscv-tests/isa/rv64ua-* ../../riscv-tests/isa/rv64uf-* ../../riscv-tests/isa/rv64ud-* ../../riscv-tests/isa/rv64uc-* ../../riscv-tests/isa/rv64si-* ../../riscv-tests/isa/rv64mi-* | grep -v .dump`)

else
	files=$@
fi

rm iss.log
for file_name in "${files[@]}"; do
	echo "[TESTBENCH] execute test ${file_name}" >> iss.log
	./obj_dir/Vtb_iss +ELF=${file_name} >> iss.log
done
