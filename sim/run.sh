#!/bin/bash

if [ $# -eq 0 ]; then
	files=(`ls -1 ../tests/rv64ui-p/*.hex`)
else
	files=$@
fi

rm iss.log
for file_name in "${files[@]}"; do
	rm rv64ui-p.hex rv64ui-p.dump
	ln -s ${file_name} rv64ui-p.hex
	ln -s ${file_name/hex/dump} rv64ui-p.dump
	echo "[TESTBENCH] execute test ${file_name}" >> iss.log
	./obj_dir/Vtb_iss >> iss.log
done
