// +build integration

package splunk

import (
	"encoding/csv"
	"encoding/json"
	"fmt"
	"io"
	"math/rand"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/stretchr/testify/suite"

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

func (suite *Suite) countResults(qry string, cond func(int) bool) (int, error) {
	podName, _ := suite.GetPodNameByPrefix("splunk")
	count, err := retry.DoWithRetryInterfaceE(suite.T(), fmt.Sprintf("Count results for: %s", qry), tests.DefaultMaxRetries, tests.DefaultRetryTimeout, func() (interface{}, error) {
		output, err := suite.RunKubectlExec(podName, "bash", "-c",
			fmt.Sprintf("curl -s -u admin:Admin123! -k https://localhost:8089/services/search/jobs/export -d output_mode=csv -d search='search %s' | wc -l", qry))
		if err != nil {
			return -1, err
		}
		if output == "" || output == "0\n" || output == "0" {
			return -1, fmt.Errorf("no results from splunk search: %s", output)
		}
		elementsOnIndex, err := strconv.Atoi(output)
		if err != nil {
			return -1, err
		}
		if cond(elementsOnIndex) == false {
			return -1, fmt.Errorf("not enough elements")
		}
		return elementsOnIndex, nil
	})
	return count.(int), err
}

func (suite *Suite) checkResults(qry string, chk func([]string) bool) (bool, error) {
	podName, _ := suite.GetPodNameByPrefix("splunk")
	results, err := retry.DoWithRetryInterfaceE(suite.T(), fmt.Sprintf("Check results for: %s", qry), tests.DefaultMaxRetries, tests.DefaultRetryTimeout, func() (interface{}, error) {
		output, err := suite.RunKubectlExec(podName, "bash", "-c",
			fmt.Sprintf("curl -s -u admin:Admin123! -k https://localhost:8089/services/search/jobs/export -d output_mode=csv -d search='search %s'", qry))
		if err != nil {
			return "", err
		}
		if output == "" {
			return "", fmt.Errorf("no results from splunk search: %s", output)
		}
		return output, nil
	})
	suite.Nil(err)

	//fmt.Printf("\n\n\nCSV RECORDS=%s\n", results)

	reader := csv.NewReader(strings.NewReader(results.(string)))
	_, err = reader.Read()
	suite.Nil(err)

	for {
		record, err := reader.Read()
		if err == io.EOF {
			break
		}
		if len(record) == 0 {
			continue
		}
		suite.Nil(err)
		//fmt.Printf("RECORD=%+v\n", record)
		// Raw events do not get other properties set automagically...
		// we should probably pass all seven
		suite.Assert().True(chk(record))
	}
	return true, nil
}

func (suite *Suite) waitMinResults(qry string, count int) int {
	cnt, err := suite.countResults(qry, func(cnt int) bool {
		return cnt >= count
	})
	suite.Nil(err)
	suite.Assert().GreaterOrEqual(cnt, count)
	return count
}

func TestSuite(t *testing.T) {
	s := &Suite{BaseTestSuite: tests.BaseTestSuite{Name: "splunk"}}
	suite.Run(t, s)
}

func (suite *Suite) TestDummyInputToSplunkOutput() {
	random := fmt.Sprintf("%d", rand.Int())
	testID := strings.Join([]string{"dummy", random}, "-")

	k8sDeployment, _ := suite.RenderCfgFromTpl("splunk-deployment", "k8s", pongo2.Context{
		"test_id": testID,
	})

	k8s.KubectlApply(suite.T(), suite.K8sOptions, k8sDeployment)
	k8s.WaitUntilServiceAvailable(suite.T(), suite.K8sOptions, "splunk-master", 3, 1*time.Minute)

	cfg, _ := suite.RenderCfgFromTpl("dummy_input_splunk_output", "values", pongo2.Context{
		"test_id": testID,
	})
	opts, _ := suite.GetTerraformOpts(cfg)

	defer terraform.Destroy(suite.T(), opts)
	terraform.InitAndApply(suite.T(), opts)

	// wait for records to appear
	suite.waitMinResults(testID, 1)
	suite.waitMinResults(fmt.Sprintf("test_id=%s raw=on", testID), 1)
	suite.waitMinResults(fmt.Sprintf("test_id=%s raw=off", testID), 1)
	suite.waitMinResults(fmt.Sprintf("event.test_id=%s event.raw=on event.nested=on", testID), 1)

	suite.waitMinResults(
		fmt.Sprintf("event.test_id=%s event.raw=on event.nested=on", testID), 1)
	suite.checkResults(fmt.Sprintf("event.test_id=%s event.raw=on event.nested=on", testID),
		func(record []string) bool {
			raw := struct {
				Event struct {
					Message string `json:"message"`
					Raw     string `json:"raw"`
					Nested  string `json:"nested"`
				} `json:"event"`
			}{}
			if err := json.Unmarshal([]byte(record[7]), &raw); err != nil {
				suite.Nil(err)
				return false
			}

			suite.Assert().Equal("dummy", raw.Event.Message)
			suite.Assert().Equal("on", raw.Event.Raw)
			suite.Assert().Equal("on", raw.Event.Nested)

			return raw.Event.Message == "dummy" &&
				raw.Event.Raw == "on" &&
				raw.Event.Nested == "on"
		})

	suite.waitMinResults(
		fmt.Sprintf("test_id=%s raw=on nested=off", testID), 1)
	suite.checkResults(fmt.Sprintf("test_id=%s raw=on nested=off", testID),
		func(record []string) bool {
			raw := struct {
				Message string `json:"message"`
				Raw     string `json:"raw"`
				Nested  string `json:"nested"`
			}{}
			fmt.Printf("RECORD=%s\n", record[7])
			if err := json.Unmarshal([]byte(record[7]), &raw); err != nil {
				suite.Nil(err)
				return false
			}
			suite.Assert().Equal("dummy", raw.Message)
			suite.Assert().Equal("on", raw.Raw)
			suite.Assert().Equal("off", raw.Nested)

			return raw.Message == "dummy" &&
				raw.Raw == "on" &&
				raw.Nested == "off"
		})

}
