SHELL := /bin/bash
FIRST_GOAL := $(firstword $(MAKECMDGOALS))
EXTRA_GOALS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))

.PHONY: k3s-vm-lab doctor build status report destroy test syntax

k3s-vm-lab:
	@./scripts/k3s-vm-lab $(EXTRA_GOALS)

doctor build status report destroy:
	@if [ "$(FIRST_GOAL)" = "$@" ]; then ./scripts/k3s-vm-lab $@ $(filter-out $@,$(MAKECMDGOALS)); fi

syntax:
	@find scripts tests -type f \( -name '*.sh' -o -name 'k3s-vm-lab' \) -print0 | xargs -0 -n1 bash -n

test: syntax
	@./tests/integration/mock_build_test.sh
	@./tests/integration/mock_failure_cleanup_test.sh
	@./tests/integration/incomplete_cluster_test.sh
	@./tests/integration/cluster_index_test.sh
	@./tests/integration/custom_resources_test.sh
	@./tests/integration/safe_destroy_test.sh
	@./tests/integration/fake_gpu_failure_test.sh
	@./tests/integration/fake_gpu_wait_test.sh

%:
	@:
