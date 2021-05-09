package bug3398

import (
	"fmt"
	"github.com/calyptia/fluent-bit-ci/long-run/tests"
	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"time"
)

type Suite struct {
	tests.BaseTestSuite
}

const MaxRetries = 25
const RetrySleepInterval = 1 * time.Minute

func (suite *Suite) TestTailInputLoad() {
	cfg, _ := suite.RenderCfgFromTpl("tail_input", "", nil)
	opts, _ := suite.GetTerraformOpts(cfg)

	defer terraform.Destroy(suite.T(), opts)
	terraform.InitAndApply(suite.T(), opts)

	podName, err := suite.GetPodNameByPrefix("fluent-bit")
	suite.Nil(err)

	pod, err := k8s.GetPodE(suite.T(), suite.K8sOptions, podName)
	suite.Nil(err)

	_, err = suite.RunKubectlExec(podName, "/bin/sh", "-c",
		"/run_log_generator.py --log-size-in-bytes 1000 --log-rate 200000 --log-agent-input-type tail --tail-file-path /tmp/test.log > /dev/null 2> /dev/null &")
	suite.Nil(err)

	retry.DoWithRetry(suite.T(), "check if pod has crashed",
		MaxRetries, RetrySleepInterval, func() (string, error) {
			return func() (string, error) {
				suite.True(k8s.IsPodAvailable(pod))
				return "", fmt.Errorf("pod: %s still running, retrying", pod.Name)
			}()
	})
}
