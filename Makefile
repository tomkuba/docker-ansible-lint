ifneq (,)
.error This Makefile requires GNU Make.
endif

.PHONY: build rebuild test _test_version _test_run tag pull login push enter

CURRENT_DIR = $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

DIR = .
FILE = Dockerfile
IMAGE = cytopia/ansible-lint
TAG = latest

build:
	docker build --build-arg VERSION=$(TAG) -t $(IMAGE) -f $(DIR)/$(FILE) $(DIR)

rebuild: pull
	docker build --no-cache --build-arg VERSION=$(TAG) -t $(IMAGE) -f $(DIR)/$(FILE) $(DIR)

test:
	@$(MAKE) --no-print-directory _test_version
	@$(MAKE) --no-print-directory _test_run

_test_version:
	@echo "------------------------------------------------------------"
	@echo "- Testing correct version"
	@echo "------------------------------------------------------------"
	@if [ "$(TAG)" = "latest" ]; then \
		echo "Fetching latest version from GitHub"; \
		LATEST="$$( \
			curl -L -sS  https://github.com/ansible/ansible-lint/releases/latest/ \
				| tac | tac \
				| grep -Eo "ansible/ansible-lint/releases/tag/v[.0-9]+" \
				| head -1 \
				| sed 's/.*v//g' \
		)"; \
		echo "Testing for latest: $${LATEST}"; \
		if ! docker run --rm $(IMAGE) ansible-lint --version | grep -E "v?$${LATEST}$$"; then \
			echo "Failed"; \
			exit 1; \
		fi; \
	else \
		echo "Testing for tag: $(TAG)"; \
		if ! docker run --rm $(IMAGE) ansible-lint --version | grep -E "v?$(TAG)$$"; then \
			echo "Failed"; \
			exit 1; \
		fi; \
	fi; \
	echo "Success"; \

_test_run:
	@echo "------------------------------------------------------------"
	@echo "- Testing playbook"
	@echo "------------------------------------------------------------"
	@if ! docker run --rm -v $(CURRENT_DIR)/tests:/data $(IMAGE) ansible-lint -v playbook.yml; then \
		echo "Failed"; \
		exit 1; \
	fi; \
	echo "Success";

tag:
	docker tag $(IMAGE) $(IMAGE):$(TAG)

pull:
	@grep -E '^\s*FROM' Dockerfile \
		| sed -e 's/^FROM//g' -e 's/[[:space:]]*as[[:space:]]*.*$$//g' \
		| xargs -n1 docker pull;

login:
	yes | docker login --username $(USER) --password $(PASS)

push:
	@$(MAKE) tag TAG=$(TAG)
	docker push $(IMAGE):$(TAG)

enter:
	docker run --rm --name $(subst /,-,$(IMAGE)) -it --entrypoint=/bin/sh $(ARG) $(IMAGE):$(TAG)
