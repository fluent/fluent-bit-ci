package elasticsearch

import (
	"fmt"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/calyptia/fluent-bit-ci/integration/tests"
	"time"
)

type Suite struct {
	tests.BaseTestSuite
}

func (suite *Suite) TestDummyInputToElasticSearchOutput() {

	cfg, _ := suite.RenderCfgFromTpl("dummy_input_es_output", nil)
	opts, _ := suite.GetTerraformOpts(map[string]interface{}{
		"fluent-bit-config": cfg,
	})

	defer terraform.Destroy(suite.T(), opts)
	terraform.InitAndApply(suite.T(), opts)

	status := retry.DoWithRetry(suite.T(), "Check if fluentbit index exists", 3, 1*time.Minute, func() (string, error) {
		output, err := suite.RunKubectlExec("elasticsearch-master-0", "curl", "-s", "-w", "%{http_code}", "http://localhost:9200/fluentbit/_search/", "-o", "/dev/null")
		if output != "200" || err != nil {
			return "", fmt.Errorf("Not found index /fluentbit")
		}
		return output, nil
	})

	suite.Equal("200", status)
}

