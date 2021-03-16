package tests

import (
	"fmt"
	"github.com/flosch/pongo2/v4"
	http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/suite"
	"io/ioutil"
	"os"
	"os/exec"
	"path"
	"strings"
	"time"
)

const defaultk8sClientConfigPath = "/tmp/client.config"
const defaultk8sImageRepository = "fluentbitdev/fluent-bit"
const defaultK8sImageTag = "x86_64-master"


type BaseTestSuite struct {
	suite.Suite
	Name, Namespace string
	k8sOptions *k8s.KubectlOptions
}

func (suite *BaseTestSuite) RenderCfgFromTpl(tplName string, ctx pongo2.Context) (string, error) {
	templatePath := path.Join("tests", suite.Name , "templates", "values", tplName + ".yaml")
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

	if ctx == nil {
		ctx = pongo2.Context{
			"image_repository": getEnv("IMAGE_REPOSITORY", defaultk8sImageRepository),
			"image_tag": getEnv("IMAGE_TAG", defaultK8sImageTag),
		}
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


func getEnv(key string, defaultVal string) string {
	if value, exists := os.LookupEnv(key); exists {
		return value
	}
	return defaultVal
}

func (suite *BaseTestSuite) GetTerraformOpts(extendedOpts map[string]interface{}) (*terraform.Options, error){
	var variables = make(map[string]interface{})
	variables["namespace"] = suite.Namespace

	if extendedOpts != nil {
		for name, value := range extendedOpts {
			variables[name] = value
		}
	}

	return terraform.WithDefaultRetryableErrors(suite.T(), &terraform.Options{
		TerraformDir: path.Join(".", "tests", suite.Name),
		Vars: variables,
	}), nil
}

func (suite *BaseTestSuite) TearDownSuite() {
	defer k8s.DeleteNamespace(suite.T(), suite.k8sOptions, suite.Namespace)
}

func (suite *BaseTestSuite) SetupSuite() {
	suite.Namespace = fmt.Sprintf("test-%s-%s", suite.Name, strings.ToLower(random.UniqueId()))
	kubeConfigPath := getEnv("KUBECONFIG", defaultk8sClientConfigPath)
	input, err := ioutil.ReadFile(kubeConfigPath)
	if err != nil {
		panic(err)
	}

	testSuitek8sConfigPath := path.Join(".", "tests", suite.Name, "client.config")
	err = ioutil.WriteFile(testSuitek8sConfigPath, input, 0700)
	if err != nil {
		panic(err)
	}

	suite.k8sOptions = k8s.NewKubectlOptions("", testSuitek8sConfigPath, suite.Namespace)
	k8s.CreateNamespace(suite.T(), suite.k8sOptions, suite.Namespace)
}

func (suite *BaseTestSuite) RunKubectlExec(podName string, cmds...string) (string, error){
	var args = []string{"kubectl", "exec", "-n", suite.Namespace, "--kubeconfig", suite.k8sOptions.ConfigPath, podName, "--"}
	for _, cmd := range cmds {
		args = append(args, cmd)
	}
	output, err := exec.Command(args[0], args[1:]...).CombinedOutput()
	return string(output), err
}

func(suite *BaseTestSuite) AssertPodURL(uri string, port int, podName string, status, retries int, sleep time.Duration) {
	var retStatus int

	tunnel := k8s.NewTunnel(suite.k8sOptions, k8s.ResourceTypePod, podName, 0, port)
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
