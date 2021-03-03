# Integration tests
TIMEOUT ?= 3600s

# Make target definitions
default:
	@echo "Nothing to make. Run 'make integration' to run integration tests."

.PHONY: integration
integration:
	cd integration && go test -timeout $(TIMEOUT) . --tags=integration -v
