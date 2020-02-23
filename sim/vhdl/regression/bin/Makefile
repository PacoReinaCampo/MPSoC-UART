all: build

build:
	@if [ ! -e work ]; then vlib work; fi
	@vcom -2008 -f msi.vc
	vsim -c -do run.do work.mpsoc_msi_testbench
