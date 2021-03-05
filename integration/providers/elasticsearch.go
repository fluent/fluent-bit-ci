package providers

import (
	"fmt"
	"github.com/gruntwork-io/terratest/modules/helm"
	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/random"
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

const defaultRetries = 10
const defaultSleepPeriod = 30 * time.Second

func (suite *ElasticSearchSuite) TearDownTest() {
	suite.RemoveCharts()
}

func (suite *ElasticSearchSuite) SetupTest() {
	var ElasticSearchCharts = []ChartToInstall{
		{fmt.Sprintf("fluent-bit-%s", strings.ToLower(random.UniqueId())),"https://fluent.github.io/helm-charts","fluent","fluent/fluent-bit",suite.helmOpts	},
		{fmt.Sprintf("elasticsearch-%s", strings.ToLower(random.UniqueId())), "https://helm.elastic.co","elastic", "elastic/elasticsearch",&helm.Options{
			KubectlOptions: suite.kubectlOpts,
			SetValues: map[string]string{"replicas": "1", "minMasterNodes": "1"}}},
	}

	for _, chart := range ElasticSearchCharts {
		suite.InstallChart(chart)
	}

	k8s.WaitUntilPodAvailable(suite.T(), suite.kubectlOpts, suite.GetPodNameByChartRelease("fluent"), defaultRetries, defaultSleepPeriod)
	k8s.WaitUntilPodAvailable(suite.T(), suite.kubectlOpts, "elasticsearch-master-0", defaultRetries, defaultSleepPeriod)
}

const elasticSearchSleepPeriod = 15 * time.Second

func (suite *ElasticSearchSuite) TestFluentbitOutputToElasticSearch() {
	suite.assertHTTPResponseFromPod("/fluentbit/_search/", 9200, "elasticsearch-master-0", 200, defaultRetries, elasticSearchSleepPeriod)
}
