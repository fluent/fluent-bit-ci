// +build long-run

package tests

import (
	"flag"
	"fmt"
	http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/suite"
	"io/ioutil"
	v1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"os"
	"os/exec"
	"path"
	"strings"
	"time"
)

const defaultk8sClientConfigPath = "/tmp/client.config"
const defaultk8sImageRepository = "fluentbitdev/fluent-bit"
const defaultK8sImageTag = "x86_64-master"
const DefaultMaxRetries = 3
const DefaultRetryTimeout = 1 * time.Minute

var InputRate = flag.Int("rate", 0, "Input rate value")

type BaseTestSuite struct {
	suite.Suite
	Name, Namespace  string
	K8sOptions       *k8s.KubectlOptions
	TerraformOptions map[string]string
	InputRate        int
}

func (suite *BaseTestSuite) GetPodNameByPrefix(prefix string) (string, error) {
	var podName string = ""
	for _, pod := range k8s.ListPods(suite.T(), suite.K8sOptions, v1.ListOptions{}) {
		if strings.Contains(pod.Name, prefix) {
			podName = pod.Name
			break
		}
	}
	if podName == "" {
		return "", fmt.Errorf("not found pod for prefix: %s", prefix)
	}
	return podName, nil
}

func (suite *BaseTestSuite) RenderCfgFromTpl(tplName string, prefix string, extendedContext pongo2.Context) (string, error) {
	if prefix == "" {
		prefix = "values"
	}
	templatePath := path.Join("tests", suite.Name, "templates", prefix, tplName+".yaml")
	if _, err := os.Stat(templatePath); os.IsNotExist(err) {
		return "", err
	}

	tpl, err := pongo2.FromFile(templatePath)
	if err != nil {
		return "", err
	}

	tempFile, err := ioutil.TempFile(path.Join(".", "tests", suite.Name), "test")
	if err != nil {
		return "", err
	}

	ctx := pongo2.Context{
		"image_repository": GetEnv("IMAGE_REPOSITORY", defaultk8sImageRepository),
		"image_tag":        GetEnv("IMAGE_TAG", defaultK8sImageTag),
		"namespace":        suite.Namespace,
		"suite":            suite.Name,
	}

	if extendedContext != nil {
		ctx.Update(extendedContext)
	}

	renderedTemplate, err := tpl.Execute(ctx)
	if err != nil {
		return "", err
	}

	//return renderedTemplate, nil
	_, err = tempFile.Write([]byte(renderedTemplate))
	if err != nil {
		return "", err
	}

	return tempFile.Name(), err
}

func GetEnv(key string, defaultVal string) string {
	if value, exists := os.LookupEnv(key); exists {
		return value
	}
	return defaultVal
}

func (suite *BaseTestSuite) GetTerraformOpts(fluentBitConfig string) (*terraform.Options, error) {
	var variables = make(map[string]interface{})
	variables["namespace"] = suite.Namespace
	variables["fluent-bit-config"] = fluentBitConfig

	for k, v := range suite.TerraformOptions {
		variables[k] = v
	}

	return terraform.WithDefaultRetryableErrors(suite.T(), &terraform.Options{
		TerraformDir: path.Join(".", "tests", suite.Name),
		Vars:         variables,
	}), nil
}

func (suite *BaseTestSuite) TearDownSuite() {
	defer k8s.DeleteNamespace(suite.T(), suite.K8sOptions, suite.Namespace)
}

func (suite *BaseTestSuite) SetupSuite() {
	suite.Namespace = fmt.Sprintf("test-benchmark-%s-%d-%s", suite.Name, *InputRate, strings.ToLower(random.UniqueId()))
	suite.InputRate = *InputRate
	kubeConfigPath := GetEnv("KUBECONFIG", defaultk8sClientConfigPath)
	input, err := ioutil.ReadFile(kubeConfigPath)
	if err != nil {
		panic(err)
	}

	testSuitek8sConfigPath := path.Join(".", "tests", suite.Name, "client.config")
	err = ioutil.WriteFile(testSuitek8sConfigPath, input, 0700)
	if err != nil {
		panic(err)
	}

	suite.K8sOptions = k8s.NewKubectlOptions("", testSuitek8sConfigPath, suite.Namespace)
	k8s.CreateNamespace(suite.T(), suite.K8sOptions, suite.Namespace)

	if suite.TerraformOptions == nil {
		suite.TerraformOptions = make(map[string]string)
	}

	suite.TerraformOptions["prometheus-config"] = prometheusCfg
	suite.TerraformOptions["nfs-server"] = GetEnv("NFS_SERVER", "")
	suite.TerraformOptions["nfs-path"] = GetEnv("NFS_PATH", "")
}

func (suite *BaseTestSuite) RunKubectlExec(podName string, cmds ...string) (string, error) {
	var args = []string{"kubectl", "exec", "-n", suite.Namespace, "--kubeconfig", suite.K8sOptions.ConfigPath, podName, "--"}
	for _, cmd := range cmds {
		args = append(args, cmd)
	}
	output, err := exec.Command(args[0], args[1:]...).CombinedOutput()
	return strings.TrimSuffix(string(output), "\n"), err
}

func (suite *BaseTestSuite) AssertPodURL(uri string, port int, podName string, status, retries int, sleep time.Duration) {
	var retStatus int

	tunnel := k8s.NewTunnel(suite.K8sOptions, k8s.ResourceTypePod, podName, 0, port)
	defer tunnel.Close()
	tunnel.ForwardPort(suite.T())
	endpoint := fmt.Sprintf("http://%s%s", tunnel.Endpoint(), uri)
	http_helper.HttpGetWithRetryWithCustomValidation(
		suite.T(),
		endpoint,
		nil,
		retries,
		sleep,
		func(statusCode int, body string) bool {
			retStatus = statusCode
			return statusCode == status && body != ""
		},
	)

	assert.Equal(suite.T(), status, retStatus)
}
