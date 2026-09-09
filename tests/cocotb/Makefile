# Copyright (c) 2025-2026 Antmicro <www.antmicro.com>
# SPDX-License-Identifier: Apache-2.0

ALL_TEST_DIRS := uart_core_ahb i3c streaming-boot-axi-dualcore
ifneq ($(strip $(COCOTB_TEST)),)
ifeq ($(filter $(COCOTB_TEST),$(ALL_TEST_DIRS)),)
$(error Unknown COCOTB_TEST: $(COCOTB_TEST))
endif
TEST_DIRS := $(COCOTB_TEST)
else
TEST_DIRS := $(ALL_TEST_DIRS)
endif

RESULT_NAME := $(if $(strip $(COCOTB_TESTCASE)),$(COCOTB_TESTCASE),all)
TEST_RESULTS := $(addsuffix /results/$(RESULT_NAME).xml,$(TEST_DIRS))

verify: venv $(TEST_RESULTS)
	. venv/bin/activate;\
	junitparser verify $(TEST_RESULTS)

$(TEST_RESULTS): venv FORCE
	mkdir -p $(dir $@)
	. venv/bin/activate;\
	$(MAKE) -C $(patsubst %/results/,%,$(dir $@)) all \
		COVERAGE_TYPE=branch \
		TESTCASE="$(COCOTB_TESTCASE)" \
		COCOTB_RESULTS_FILE="results/$(RESULT_NAME).xml";

FORCE:

clean:
	-rm -r venv build *.egg-info */dump.fst */results.xml */results */coverage.dat */sim-build-*

venv: venv/touchfile
venv/touchfile: pyproject.toml
	python3 -m venv venv
	. venv/bin/activate; pip install .
	touch venv/touchfile

dirs:
	echo $(TEST_DIRS)

.PHONY: all test venv clean dirs verify FORCE
