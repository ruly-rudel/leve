#!/bin/bash

if [ $# -eq 0 ]; then
	#files=(`ls -1 ../tests/rv64ui-p/*.dump ../tests/rv64um-p/*.dump ../tests/rv64ua-p/*.dump ../tests/rv64uf-p/*.dump ../tests/rv64si-p/*.dump`)
	files=(`ls -1 ../tests/rv64ui-p/*.dump ../tests/rv64um-p/*.dump ../tests/rv64ua-p/*.dump ../tests/rv64uf-p/*.dump`)
else
	files=$@
fi

rm iss.log
for file_name in "${files[@]}"; do
	rm rv64ui-p.dump rv64ui-p
	ln -s ${file_name} rv64ui-p.dump
	ln -s ${file_name/.dump/} rv64ui-p
	echo "[TESTBENCH] execute test ${file_name/.dump/}" >> iss.log
	./obj_dir/Vtb_iss >> iss.log
done
