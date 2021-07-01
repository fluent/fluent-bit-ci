package integration

import (
	"testing"

	"github.com/calyptia/fluent-bit-ci/integration/tests"
	"github.com/calyptia/fluent-bit-ci/integration/tests/bigquery"
	"github.com/calyptia/fluent-bit-ci/integration/tests/elasticsearch"
	"github.com/calyptia/fluent-bit-ci/integration/tests/splunk"

	"github.com/calyptia/fluent-bit-ci/integration/tests/stackdriver"
	"github.com/stretchr/testify/suite"
)

func TestFluentBitSuites(t *testing.T) {
	suite.Run(t, &elasticsearch.Suite{BaseTestSuite: tests.BaseTestSuite{Name: "elasticsearch"}})
	suite.Run(t, &splunk.Suite{BaseTestSuite: tests.BaseTestSuite{Name: "splunk"}})
	suite.Run(t, &bigquery.Suite{BaseTestSuite: tests.BaseTestSuite{Name: "bigquery"}})
	suite.Run(t, &stackdriver.Suite{BaseTestSuite: tests.BaseTestSuite{Name: "stackdriver"}})
}
