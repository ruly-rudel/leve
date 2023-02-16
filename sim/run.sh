#!/bin/bash

if [ $# -eq 0 ]; then
	files=(`ls -1 ../tests/rv64ui-p/* ../tests/rv64um-p/* ../tests/rv64ua-p/* ../tests/rv64uf-p/* ../tests/rv64ud-p/* ../tests/rv64si-p/* ../tests/rv64uc-p/* | grep -v .dump`)
else
	files=$@
fi

rm iss.log
for file_name in "${files[@]}"; do
	echo "[TESTBENCH] execute test ${file_name}" >> iss.log
	./obj_dir/Vtb_iss +ELF=${file_name} >> iss.log
done
