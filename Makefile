# Make target definitions
default:
	@echo "Nothing to make. Run 'make integration' to run integration tests."

.PHONY: integration
integration:
	./run-tests.sh
