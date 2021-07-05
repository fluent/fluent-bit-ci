package integration

import (
	"testing"

	"github.com/calyptia/fluent-bit-ci/integration/tests"
	_ "github.com/calyptia/fluent-bit-ci/integration/tests/stdout"
	"github.com/stretchr/testify/suite"
)

func TestFluentBitSuites(t *testing.T) {
	for _, s := range tests.GetSuites() {
		suite.Run(t, s)
	}
}
