package providers

import (
	"fmt"
	"github.com/gruntwork-io/terratest/modules/helm"
	http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/stretchr/testify/assert"
	"strings"
	"time"
)

type ElasticSearchSuite struct {
	*BaseFluentbitSuite
}

const DefaultElasticsearchConfig =`
  service: |
    [SERVICE] 
        Flush        5
        Daemon       Off
        Log_Level    debug
        HTTP_Server On
        HTTP_Listen 0.0.0.0
        HTTP_Port {{ .Values.service.port }}
  inputs: |
    [INPUT]
        Name    tail
        Path    /var/log/syslog
  outputs: |
    [OUTPUT]
        Name    es
        Match   *
        Host    elasticsearch-master
        Port    9200
        Index   fluentbit
 `

func (suite *ElasticSearchSuite) TearDownTest() {
	suite.RemoveCharts()
}

func (suite *ElasticSearchSuite) SetupTest() {
	var ElasticSearchCharts = []ChartToInstall{
		{
			fmt.Sprintf("fluent-bit-%s", strings.ToLower(random.UniqueId())),
			"https://fluent.github.io/helm-charts",
			"fluent",
			"fluent/fluent-bit",
			suite.helmOpts,
		},
		{
			fmt.Sprintf("elasticsearch-%s", strings.ToLower(random.UniqueId())),
			"https://helm.elastic.co",
			"elastic",
			"elastic/elasticsearch",
			&helm.Options{
				KubectlOptions: suite.kubectlOpts,
				SetValues: map[string]string{"replicas": "1", "minMasterNodes": "1"}},
		},
	}

	for _, chart := range ElasticSearchCharts {
		suite.InstallChart(chart)
	}
}

func (suite *ElasticSearchSuite) TestFluentbitOutputToElasticSearch() {
	retries := 15
	sleep := 1 * time.Minute

	// TODO: move this into a util part of the base test type
	k8s.WaitUntilPodAvailable(suite.T(), suite.kubectlOpts, suite.GetPodNameByChartRelease("fluent"), retries, sleep)

	tunnel := k8s.NewTunnel(suite.kubectlOpts, k8s.ResourceTypePod, "elasticsearch-master-0", 0, 9200)
	defer tunnel.Close()
	tunnel.ForwardPort(suite.T())

	endpoint := fmt.Sprintf("http://%s/fluentbit/_search/", tunnel.Endpoint())
	http_helper.HttpGetWithRetryWithCustomValidation(
		suite.T(),
		endpoint,
		nil,
		retries,
		sleep,
		func(statusCode int, body string) bool {
			assert.Equal(suite.T(), 200, statusCode)
			assert.NotEmpty(suite.T(), body)
			return statusCode == 200 && body != ""
		},
	)
}