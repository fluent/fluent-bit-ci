# Integration tests
TIMEOUT ?= 3600s

# Make target definitions
default:
	@echo "Nothing to make. Run 'make integration' to run integration tests."

.PHONY: integration
integration:
	cd integration && go test -timeout $(TIMEOUT) . --tags=integration -v

RATES = 100 1000 10000
benchmark:
	$(foreach var, $(RATES), cd integration && go test -timeout $(TIMEOUT) . --tags=benchmark -v -rate=$(var) && cd ../;)

long-run:
    cd integration && go test . --tags=long-run -v
