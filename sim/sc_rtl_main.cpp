#include <systemc.h>
#include <verilated.h>
#if VM_TRACE
#include <verilated_vcd_sc.h>
#endif

#include "Vtb_rtl.h"

int sc_main(int argc, char** argv)
{
	Verilated::commandArgs(argc, argv);

	sc_clock clk{"clk", 10, SC_NS, 0.5, 3, SC_NS, true};
	sc_signal < bool > rstn;
	Vtb_rtl* tb_rtl = new Vtb_rtl{"tb_rtl"};
	tb_rtl->CLK(clk);
	tb_rtl->RSTn(rstn);

	// sim one tick before trace on
	sc_core::sc_start(sc_core::SC_ZERO_TIME);

	// trace on
#if VM_TRACE
	Verilated::traceEverOn(true);
	VerilatedVcdSc* tfp = new VerilatedVcdSc;
	tb_iss->trace(tfp, 99);
	tfp->open("simx.vcd");
#endif
	
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
#if VM_TRACE
	tfp->close();
#endif
	delete tb_rtl;

	return 0;
}
