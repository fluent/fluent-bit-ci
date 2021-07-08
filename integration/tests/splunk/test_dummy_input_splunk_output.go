// +build integration

package splunk

import (
	"fmt"
	"math/rand"
	"strconv"
	"strings"
	"time"

	"github.com/calyptia/fluent-bit-ci/integration/tests"
	"github.com/flosch/pongo2/v4"
	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/gruntwork-io/terratest/modules/terraform"
)

type Suite struct {
	tests.BaseTestSuite
}

type result struct {
	Raw     string `json:"_raw"`
	LastRow bool   `json:"lastrow"`
}

type header struct {
	Result result `json:"result"`
}

func (suite *Suite) waitCountResults(qry string, cnt int) int {
	podName, _ := suite.GetPodNameByPrefix("splunk")
	count, err := retry.DoWithRetryInterfaceE(suite.T(), fmt.Sprintf("Count results for: %s", qry), tests.DefaultMaxRetries, tests.DefaultRetryTimeout, func() (interface{}, error) {
		output, err := suite.RunKubectlExec(podName, "bash", "-c",
			fmt.Sprintf("curl -s -u admin:Admin123! -k https://localhost:8089/services/search/jobs/export -d output_mode=csv -d search='%s' | wc -l", qry))
		if err != nil {
			return "", err
		}
		if output == "" || output == "0\n" || output == "0" {
			return "", fmt.Errorf("no results from splunk search")
		}
		elementsOnIndex, err := strconv.Atoi(output)
		if err != nil {
			return nil, err
		}
		if elementsOnIndex < cnt {
			return nil, err
		}
		return elementsOnIndex, nil
	})
	suite.Nil(err)
	return count.(int)
}

func (suite *Suite) countResults(qry string) int {
	podName, _ := suite.GetPodNameByPrefix("splunk")
	count, err := retry.DoWithRetryInterfaceE(suite.T(), fmt.Sprintf("Count results for: %s", qry), tests.DefaultMaxRetries, tests.DefaultRetryTimeout, func() (interface{}, error) {
		output, err := suite.RunKubectlExec(podName, "bash", "-c",
			fmt.Sprintf("curl -s -u admin:Admin123! -k https://localhost:8089/services/search/jobs/export -d output_mode=csv -d search='%s' | wc -l", qry))
		if err != nil {
			return "", err
		}
		if output == "" || output == "0\n" || output == "0" {
			return "", fmt.Errorf("no results from splunk search")
		}
		elementsOnIndex, err := strconv.Atoi(output)
		if err != nil {
			return nil, err
		}
		return elementsOnIndex, nil
	})

	suite.Nil(err)
	return count.(int)
}

func (suite *Suite) TestDummyInputToSplunkOutput() {
	random := fmt.Sprintf("%d", rand.Int())
	testID := strings.Join([]string{"dummy", random}, "-")

	k8sDeployment, _ := suite.RenderCfgFromTpl("splunk-deployment", "k8s", pongo2.Context{
		"test_id": testID,
	})

	k8s.KubectlApply(suite.T(), suite.K8sOptions, k8sDeployment)
	k8s.WaitUntilServiceAvailable(suite.T(), suite.K8sOptions, "splunk-master", 3, 1*time.Minute)

	cfg, _ := suite.RenderCfgFromTpl("dummy_input_splunk_output", "values", nil)
	opts, _ := suite.GetTerraformOpts(cfg)

	defer terraform.Destroy(suite.T(), opts)
	terraform.InitAndApply(suite.T(), opts)

	// wait for both records to appear, both raw and JSON parsed
	suite.waitCountResults(testID, 2)
	// and then see if we only get one event that can be searched as if
	// it was parsed as JSON
	suite.waitCountResults(fmt.Sprintf("test_id=%s", testID), 1)
}
