// +build long-run

package test_3398

import (
	"github.com/calyptia/fluent-bit-ci/integration/tests"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"time"
)

type Suite struct {
	tests.BaseTestSuite
}

func (suite *Suite) TestDummyInputToElasticSearchOutput() {
	cfg, _ := suite.RenderCfgFromTpl("tail_input", "", nil)
	opts, _ := suite.GetTerraformOpts(cfg)

	defer terraform.Destroy(suite.T(), opts)
	terraform.InitAndApply(suite.T(), opts)

	time.Sleep(15*time.Minute)
}
