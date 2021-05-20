package bigquery

import (
	"github.com/calyptia/fluent-bit-ci/integration/tests"
	"github.com/flosch/pongo2/v4"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"time"
)

type Suite struct {
	tests.BaseTestSuite
}

const WaitInterval = 30 * time.Minute

func (suite *Suite) TestDummyInputBigQueryOutput() {
	cfg, _ := suite.RenderCfgFromTpl("dummy_input_bigquery_output", "", nil)
	opts, _ := suite.GetTerraformOpts(cfg)

	defer terraform.Destroy(suite.T(), opts)
	terraform.InitAndApply(suite.T(), opts)

	////pod, err := k8s.GetPodE(suite.T(), suite.K8sOptions, podName)
	////suite.Nil(err)
	//
	//_, err = suite.RunKubectlExec(podName, "/bin/sh", "-c",
	//	"rm -fr /data/test.log && /run_log_generator.py --log-size-in-bytes 1000 --log-rate 200000 --log-agent-input-type tail --tail-file-path /data/test.log > /dev/null 2> /dev/null &")
	//suite.Nil(err)

	time.Sleep(WaitInterval)
}
