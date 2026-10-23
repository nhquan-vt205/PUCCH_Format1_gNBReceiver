##############################################################################################
# Simulation environment of pucch_f1_rx_core
#   Simulation / waveform / coverage : QuestaSim 2021 (vlog, vsim, vcover)
#   Schematic                         : Vivado (RTL elaboration of rtl.f)
# Example run string: make TESTNAME={name_of_testcase} {optional}
#                     make TESTNAME=TC_PUCCH_F1_RX_CORE_002 all
#                     make DATA_IN=<input.txt> DATA_OUT=<output.txt> all   (paths relative to sim/)
#                     make gen_data   (rebuild the default data pair from doc/database/)
#                     make schematic SCH=u_ctrl
##############################################################################################
#Define variables
TESTNAME     ?= TC_PUCCH_F1_RX_CORE_001
TB_NAME      ?= tb_pucch_f1_rx_core
RADIX        ?= decimal
REGRESS_LIST ?= pat.list

# Test data: input file in doc/database/input/, reference file in doc/database/output/
DATA_IN      ?= ../doc/database/input/pucch_f1_rx_core_input.txt
DATA_OUT     ?= ../doc/database/output/pucch_f1_rx_core_output.txt
SIM_ARGS     ?= +IN=$(DATA_IN) +OUT=$(DATA_OUT)

# Schematic (Vivado)
DUT          ?= pucch_f1_rx_core
SCH          ?=
PART         ?= xc7a35tcpg236-1
# Vivado: $XILINX_VIVADO (set by settings64.sh), else the newest version found
# in the usual install locations, else PATH.
VIVADO_DIRS  := $(foreach d,$(HOME)/opt/Xilinx /tools/Xilinx /opt/Xilinx, \
                  $(wildcard $(d)/*/Vivado/bin $(d)/Vivado/*/bin))
VIVADO_BIN   ?= $(if $(XILINX_VIVADO),$(XILINX_VIVADO)/bin,$(lastword $(sort $(VIVADO_DIRS))))
VIVADO       := $(if $(VIVADO_BIN),$(VIVADO_BIN)/)vivado

#==============================
all: build run

all_wave: build run wave

all_cov: build_cov run_cov

build:
	mkdir -p log
	cp -rf ../testcases/$(TESTNAME).v run_test.v
	vlib work
	vmap work work
	vlog -f compile.f | tee compile.log
build_cov:
	mkdir -p log
	cp -rf ../testcases/$(TESTNAME).v run_test.v
	vlib work
	vmap work work
	vlog +cover=bcesft -f compile.f
run:
	vsim -debugDB -l $(TESTNAME).log -voptargs=+acc -assertdebug -c $(TB_NAME) $(SIM_ARGS) -do "log -r /*;run -all;"
	cp $(TESTNAME).log ./log
	mv $(TESTNAME).log sim.log
run_cov:
	vsim -coverage -l $(TESTNAME).log -c $(TB_NAME) $(SIM_ARGS) -voptargs="+cover=bcesft" -assertdebug -do "coverage save -onexit $(TESTNAME).ucdb; log -r /*;run -all"
	cp $(TESTNAME).log ./log
	mv $(TESTNAME).log sim.log
wave:
	vsim -i -view vsim.wlf -do "add wave vsim:/$(TB_NAME)/*; radix -$(RADIX)" &
schematic:
	mkdir -p log
	$(VIVADO) -mode gui -source schematic.tcl -log log/schematic.log -journal log/schematic.jou \
	  -tclargs $(DUT) $(PART) $(or $(SCH),.) rtl.f &
gen_data:
	python3 script/gen_vectors.py
gen_cov:
	mkdir -p coverage
	vcover merge IP.ucdb *.ucdb
	vcover report IP.ucdb -output coverage/summary_report.txt
	vcover report -zeros -details -code bcesft -annotate -All -codeAll IP.ucdb -output coverage/detail_report.txt
gen_html:
	mkdir -p coverage
	vcover merge IP.ucdb *.ucdb
	vcover report -zeros -details -code bcesft -annotate -testhitdataAll -html IP.ucdb
clean:
	rm -rf work
	rm -rf vsim.dbg
	rm -rf *.ini
	rm -rf *.log
	rm -rf *.wlf
	rm -rf transcript
	rm -rf *.ucdb
	rm -rf run_test.v
	rm -rf .Xil *.jou *.str
help:
	@echo ""
	@echo "****************************************"
	@echo "** make clean     : clean all compiled data"
	@echo "** make build     : build the design"
	@echo "** make build_cov : build the design in coverage mode"
	@echo "** make run       : run simulation"
	@echo "** make run_cov   : run simulation in coverage mode"
	@echo "** make all       : build and run simulation"
	@echo "** make all_cov   : build and run simulation in coverage mode"
	@echo "** make all_wave  : build and run simulation, then open waveform"
	@echo "** make wave      : open waveform (QuestaSim)"
	@echo "** make schematic : open RTL schematic (Vivado), SCH=<instance> for a sub-block"
	@echo "** make gen_data  : rebuild the test data pair from doc/database/ (script/gen_vectors.py)"
	@echo "** make gen_cov   : merge, generate coverage data base and text coverage report"
	@echo "** make gen_html  : merge, generate coverage data base and html coverage report"
	@echo "****************************************"
	@echo ""
