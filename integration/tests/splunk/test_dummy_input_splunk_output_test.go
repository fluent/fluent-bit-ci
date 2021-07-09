// +build integration

package splunk

import (
	"fmt"
	"github.com/calyptia/fluent-bit-ci/integration/tests"
	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"strconv"
	"time"
)

type Suite struct {
	tests.BaseTestSuite
}

func (suite *Suite) TestDummyInputToSplunkOutput() {
	k8sDeployment, _ := suite.RenderCfgFromTpl("splunk-deployment", "k8s", nil)

	k8s.KubectlApply(suite.T(), suite.K8sOptions, k8sDeployment)
	k8s.WaitUntilServiceAvailable(suite.T(), suite.K8sOptions, "splunk-master", 3, 1*time.Minute)

	cfg, _ := suite.RenderCfgFromTpl("dummy_input_splunk_output", "values", nil)
	opts, _ := suite.GetTerraformOpts(cfg)

	defer terraform.Destroy(suite.T(), opts)
	terraform.InitAndApply(suite.T(), opts)

	podName, _ := suite.GetPodNameByPrefix("splunk")
	elementsOnIndex := retry.DoWithRetry(suite.T(), "Check if search for testing string returns", tests.DefaultMaxRetries, tests.DefaultRetryTimeout, func() (string, error) {
		output, err := suite.RunKubectlExec(podName, "bash", "-c", "curl -s -u admin:Admin123! -k https://localhost:8089/services/search/jobs/export -d output_mode=csv -d search='search testing' | wc -l")
		if output == "0" || err != nil {
			return "", fmt.Errorf("results from splunk index search<= 0")
		}
		return output, nil
	})

	elementsOnIndexConv, err := strconv.Atoi(elementsOnIndex)
	suite.Nil(err)
	suite.Greater(elementsOnIndexConv, 0)
}
