#include <systemc.h>
#include <verilated.h>
#if VM_TRACE
#include <verilated_vcd_sc.h>
#endif

#include "VFADD_F.h"
#include <float.h>

int sc_main(int argc, char** argv)
{
	Verilated::commandArgs(argc, argv);

	sc_clock clk{"clk", 10, SC_NS, 0.5, 3, SC_NS, true};
	sc_signal < bool > rstn;
	sc_signal < uint32_t > in1;
	sc_signal < uint32_t > in2;
	sc_signal < uint32_t > out;
	sc_signal < bool >     inexact;
	sc_signal < bool >     invalid;
	VFADD_F* FADD_F = new VFADD_F{"FADD_F"};

	FADD_F->in1(in1);
	FADD_F->in2(in2);
	FADD_F->out(out);
	FADD_F->inexact(inexact);
	FADD_F->invalid(invalid);

	// sim one tick before trace on
	sc_core::sc_start(sc_core::SC_ZERO_TIME);

	// trace on
#if VM_TRACE
	Verilated::traceEverOn(true);
	VerilatedVcdSc* tfp = new VerilatedVcdSc;
	FADD_F->trace(tfp, 99);
	tfp->open("simx.vcd");
#endif
	
	/*
	while (!Verilated::gotFinish())
	{
		if (sc_time_stamp() < sc_time(10, SC_NS))
		{
			rstn = !1;
		}
		else
		{
			rstn = !0;
		}

		sc_start(1, SC_NS);
	}
	*/
	// test vector
	sc_start(1, SC_NS);
	float	in1_f;
	float	in2_f;
	float	out_f;
	uint32_t*	in1_fp = (uint32_t*)&in1_f;
	uint32_t*	in2_fp = (uint32_t*)&in2_f;
	uint32_t*	out_fp = (uint32_t*)&out_f;

	/////////////////////////////////////////////////
	//  TEST 1
	printf("[TESTBENCH] 1.0 + 1.0 = 2.0: ");
	in1_f = 1.0;
	in2_f = 1.0;
	
	in1 = *in1_fp;
	in2 = *in2_fp;
	sc_start(1, SC_NS);
	*out_fp = out;
	if(out_f == 2.0)
	{
		printf("PASS\n");
	}
	else
	{
		printf("FAIL\n");
	}
	sc_start(1, SC_NS);

	/////////////////////////////////////////////////
	//  TEST 2
	printf("[TESTBENCH] 2.0 + 1.0 = 3.0: ");
	in1_f = 2.0;
	in2_f = 1.0;
	
	in1 = *in1_fp;
	in2 = *in2_fp;
	sc_start(1, SC_NS);
	*out_fp = out;
	if(out_f == 3.0)
	{
		printf("PASS\n");
	}
	else
	{
		printf("FAIL\n");
	}
	sc_start(1, SC_NS);

	/////////////////////////////////////////////////
	//  TEST 3
	printf("[TESTBENCH] 2.0 + 2.0 = 4.0: ");
	in1_f = 2.0;
	in2_f = 2.0;
	
	in1 = *in1_fp;
	in2 = *in2_fp;
	sc_start(1, SC_NS);
	*out_fp = out;
	if(out_f == 4.0)
	{
		printf("PASS\n");
	}
	else
	{
		printf("FAIL\n");
	}
	sc_start(1, SC_NS);


	/////////////////////////////////////////////////
	//  TEST 4
	printf("[TESTBENCH] 2.0 + 0.0 = 2.0: ");
	in1_f = 2.0;
	in2_f = 0.0;
	
	in1 = *in1_fp;
	in2 = *in2_fp;
	sc_start(1, SC_NS);
	*out_fp = out;
	if(out_f == 2.0)
	{
		printf("PASS\n");
	}
	else
	{
		printf("FAIL\n");
	}
	sc_start(1, SC_NS);

	/////////////////////////////////////////////////
	//  TEST 5
	printf("[TESTBENCH] 0.0 + -2.0 = -2.0: ");
	in1_f = 0.0;
	in2_f = -2.0;
	
	in1 = *in1_fp;
	in2 = *in2_fp;
	sc_start(1, SC_NS);
	*out_fp = out;
	if(out_f == -2.0)
	{
		printf("PASS\n");
	}
	else
	{
		printf("FAIL\n");
	}
	sc_start(1, SC_NS);

	/////////////////////////////////////////////////
	//  TEST 6
	printf("[TESTBENCH] FLT_MAX + 1.0 = INF: ");
	in1_f = FLT_MAX;
	in2_f = 1.0;
	
	in1 = *in1_fp;
	in2 = *in2_fp;
	sc_start(1, SC_NS);
	*out_fp = out;
	if(out_f == in1_f + in2_f)
	{
		printf("PASS\n");
	}
	else
	{
		printf("FAIL\n");
	}
	sc_start(1, SC_NS);

	/////////////////////////////////////////////////
	//  TEST 7
	printf("[TESTBENCH] FLT_MIN - 1 = something: ");
	in1_f = FLT_MIN;
	in2_f = -1.0;
	
	in1 = *in1_fp;
	in2 = *in2_fp;
	sc_start(1, SC_NS);
	*out_fp = out;
	if(out_f == in1_f + in2_f)
	{
		printf("PASS\n");
	}
	else
	{
		printf("FAIL\n");
	}
	sc_start(1, SC_NS);

	/////////////////////////////////////////////////
	//  TEST 8
	printf("[TESTBENCH] 2.0 + -2.0 = 0.0: ");
	in1_f = 2.0;
	in2_f = -2.0;

	in1 = *in1_fp;
	in2 = *in2_fp;
	sc_start(1, SC_NS);
	*out_fp = out;
	if(out_f == 0.0)
	{
		printf("PASS\n");
	}
	else
	{
		printf("FAIL\n");
	}
	sc_start(1, SC_NS);



#if VM_TRACE
	tfp->close();
#endif
	delete FADD_F;

	return 0;
}
