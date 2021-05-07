package long_run

import (
	"github.com/calyptia/fluent-bit-ci/long-run/tests"
	"github.com/calyptia/fluent-bit-ci/long-run/tests/bug3398"
	"github.com/stretchr/testify/suite"
	"testing"
)

func TestLongRunningSuites(t *testing.T) {
	suite.Run(t, &bug3398.Suite{BaseTestSuite: tests.BaseTestSuite{Name: "bug3398"}})
}
