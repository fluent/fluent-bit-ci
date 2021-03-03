package integration

import (
	"github.com/calyptia/fluent-bit-ci/integration/providers"
	"github.com/stretchr/testify/suite"
	"testing"
)

func TestFluentBitSuites(t *testing.T) {
	provider, _ := providers.NewBaseFluentbitSuite(providers.DefaultElasticsearchConfig, "", "")
	suite.Run(t, &providers.ElasticSearchSuite{BaseFluentbitSuite: provider})
}