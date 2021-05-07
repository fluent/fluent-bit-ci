package long_run

import (
	"github.com/calyptia/fluent-bit-ci/long-run/tests"
	"github.com/calyptia/fluent-bit-ci/long-run/tests/test_3398"
	"github.com/stretchr/testify/suite"
	"testing"
)

func TestLongRunningSuites(t *testing.T) {
	suite.Run(t, &test_3398.Suite{BaseTestSuite: tests.BaseTestSuite{Name: "test-3398"}})
}
