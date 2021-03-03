package providers

import (
	"github.com/gruntwork-io/terratest/modules/helm"
	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/stretchr/testify/suite"
	"gopkg.in/yaml.v2"
	v1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"os"
	"strings"
)

type ChartToInstall struct {
	Release string
	RepoURL string
	RepoName string
	Chart string
	Opts *helm.Options
}

type BaseFluentbitSuite struct {
	suite.Suite
	config *FluentbitConfig
	kubectlOpts *k8s.KubectlOptions
	helmOpts *helm.Options
	Charts []ChartToInstall
}

type FluentbitConfig struct {
	Service       string `yaml:"service"`
	Inputs        string `yaml:"inputs"`
	Filters       string `yaml:"filters"`
	Outputs       string `yaml:"outputs"`
	CustomParsers string `yaml:"customParsers"`
}

const defaultk8sClientConfigPath = "/tmp/client.config"
const defaultK8sNamespace = "default"
const defaultk8sImageRepository = "fluentbitdev/fluent-bit"
const defaultK8sImageTag = "x86_64-master"

func NewConfigFromBytes(data []byte) (*FluentbitConfig, error) {
	var config FluentbitConfig
	var err error

	if err = yaml.Unmarshal(data, &config); err != nil {
		return nil, err
	}
	return &config, nil
}

func getEnv(key string, defaultVal string) string {
	if value, exists := os.LookupEnv(key); exists {
		return value
	}
	return defaultVal
}

func(suite *BaseFluentbitSuite) InstallChart(chart ChartToInstall) {
	helm.AddRepo(suite.T(), chart.Opts, chart.RepoName, chart.RepoURL)
	helm.Install(suite.T(), chart.Opts,chart.Chart, chart.Release)
	suite.Charts = append(suite.Charts, chart)
}

func(suite *BaseFluentbitSuite) RemoveCharts() {
	for _, chart := range suite.Charts {
		helm.Delete(suite.T(), suite.helmOpts, chart.Release, true)
	}
}

func(suite *BaseFluentbitSuite) getFluentBitHelmValuesFromConfig() map[string]string {
	var values = make(map[string]string)

	values["image.repository"] = getEnv("IMAGE_REPOSITORY", defaultk8sImageRepository)
	values["image.tag"] = getEnv("IMAGE_REPOSITORY_TAG", defaultK8sImageTag)

	if suite.config.Service != "" {
		values["config.service"] = suite.config.Service
	}
	if suite.config.Inputs != "" {
		values["config.inputs"]  = suite.config.Inputs
	}
	if suite.config.Filters != "" {
		values["config.filters"]  = suite.config.Filters
	}
	if suite.config.Outputs != "" {
		values["config.outputs"]  = suite.config.Outputs
	}
	if suite.config.CustomParsers != "" {
		values["config.customParsers"]  = suite.config.CustomParsers
	}

	return values
}

func (suite *ElasticSearchSuite) GetPodNameByChartRelease(release string) string {
	var chartName = ""
	for _, chart := range suite.Charts {
		if chart.RepoName == release {
			chartName = chart.Release
			break
		}
	}
	var podName = ""
	for _, pod := range k8s.ListPods(suite.T(), suite.kubectlOpts, v1.ListOptions{}) {
		if strings.Contains(pod.Name, chartName) {
			podName = pod.Name
			break
		}
	}
	return podName
}

func NewBaseFluentbitSuite(fluentConfig string, k8sClientPath, k8sNamespace string) (*BaseFluentbitSuite, error) {
	var baseSuite BaseFluentbitSuite
	if k8sClientPath == "" {
		k8sClientPath = defaultk8sClientConfigPath
	}
	if k8sNamespace == "" {
		k8sNamespace = defaultK8sNamespace
	}

	config, err := NewConfigFromBytes([]byte(fluentConfig))
	if err != nil {
		return nil, err
	}

	baseSuite.config = config
	baseSuite.kubectlOpts = k8s.NewKubectlOptions("", k8sClientPath, k8sNamespace)
	baseSuite.helmOpts = &helm.Options{
		SetValues: baseSuite.getFluentBitHelmValuesFromConfig(),
		KubectlOptions: baseSuite.kubectlOpts,
	}

	return &baseSuite, nil
}