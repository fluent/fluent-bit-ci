//go:build integration
// +build integration

package tests

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"io/ioutil"
	"os"
	"os/exec"
	"path"
	"strings"
	"time"

	"github.com/flosch/pongo2/v4"
	http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/gruntwork-io/terratest/modules/testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/suite"

	corev1 "k8s.io/api/core/v1"
	v1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

const defaultk8sClientConfigPath = "/tmp/client.config"
const defaultk8sImageRepository = "ghcr.io/fluent/fluent-bit/master"
const defaultK8sImageTag = "x86_64"
const DefaultMaxRetries = 3
const DefaultRetryTimeout = 1 * time.Minute

type BaseTestSuite struct {
	suite.Suite
	Name, Namespace  string
	K8sOptions       *k8s.KubectlOptions
	TerraformOptions map[string]string
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
	templatePath := path.Join("templates", prefix, tplName+".yaml")
	if _, err := os.Stat(templatePath); os.IsNotExist(err) {
		return "", err
	}

	tpl, err := pongo2.FromFile(templatePath)
	if err != nil {
		return "", err
	}

	tempFile, err := ioutil.TempFile(".", "test")
	if err != nil {
		return "", err
	}

	ctx := pongo2.Context{
		"image_repository":    GetEnv("IMAGE_REPOSITORY", defaultk8sImageRepository),
		"image_tag":           GetEnv("IMAGE_TAG", defaultK8sImageTag),
		"bigquery_dataset_id": GetEnv("GCP_BQ_DATASET_ID", ""),
		"bigquery_table_id":   GetEnv("GCP_BQ_TABLE_ID", ""),
		"namespace":           suite.Namespace,
		"suite":               suite.Name,
	}

	if extendedContext != nil {
		ctx.Update(extendedContext)
	}

	renderedTemplate, err := tpl.Execute(ctx)
	if err != nil {
		return "", err
	}

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
		TerraformDir: "./",
		Vars:         variables,
	}), nil
}

// TODO: remove once https://github.com/gruntwork-io/terratest/pull/968 available
func GetPodLogs(t testing.TestingT, options *k8s.KubectlOptions, podName string, podLogOpts *corev1.PodLogOptions) (string, error) {
	clientSet, err := k8s.GetKubernetesClientFromOptionsE(t, options)
	if err != nil {
		return "", err
	}

	req := clientSet.CoreV1().Pods(options.Namespace).GetLogs(podName, podLogOpts)
	podLogs, err := req.Stream(context.Background())
	if err != nil {
		return "", err
	}

	defer podLogs.Close()

	buf := new(bytes.Buffer)
	_, err = io.Copy(buf, podLogs)
	if err != nil {
		return "", err
	}
	str := buf.String()

	return str, nil
}

func (suite *BaseTestSuite) TearDownSuite() {
	// Get all pods and their logs in the test namespace
	for _, pod := range k8s.ListPods(suite.T(), suite.K8sOptions, v1.ListOptions{}) {
		output, err := GetPodLogs(suite.T(), suite.K8sOptions, pod.Name, &corev1.PodLogOptions{})
		if err != nil {
			fmt.Println("Unable to get logs for pod due to error", pod.Name, err)
		} else {
			fmt.Println("Logs for pod", pod.Name, output)
		}
	}

	defer k8s.DeleteNamespace(suite.T(), suite.K8sOptions, suite.Namespace)
}

func (suite *BaseTestSuite) SetupSuite() {
	suite.Namespace = fmt.Sprintf("test-%s-%s", suite.Name, strings.ToLower(random.UniqueId()))
	kubeConfigPath := GetEnv("KUBECONFIG", defaultk8sClientConfigPath)
	input, err := ioutil.ReadFile(kubeConfigPath)
	if err != nil {
		panic(err)
	}

	testSuitek8sConfigPath := "client.config"
	err = ioutil.WriteFile(testSuitek8sConfigPath, input, 0700)
	if err != nil {
		panic(err)
	}

	suite.K8sOptions = k8s.NewKubectlOptions("", testSuitek8sConfigPath, suite.Namespace)
	k8s.CreateNamespace(suite.T(), suite.K8sOptions, suite.Namespace)

	prometheusCfg, _ := suite.RenderCfgFromTpl("prometheus", "", pongo2.Context{
		"grafana_username": GetEnv("GRAFANA_USERNAME", ""),
		"grafana_password": GetEnv("GRAFANA_PASSWORD", ""),
	})

	if suite.TerraformOptions == nil {
		suite.TerraformOptions = make(map[string]string)
	}

	if _, exists := os.LookupEnv("GCP_SA_KEY"); !exists {
		panic(fmt.Errorf("Missing GCP_SA_KEY environment variable"))
	}

	testSuiteSAKeyPath := "gcp_sa_key.json"
	err = ioutil.WriteFile(testSuiteSAKeyPath, []byte(GetEnv("GCP_SA_KEY", "")), 0700)
	if err != nil {
		panic(err)
	}

	suite.TerraformOptions["gcp-sa-key"] = testSuiteSAKeyPath
	suite.TerraformOptions["prometheus-config"] = prometheusCfg
}

func (suite *BaseTestSuite) RunKubectlExec(podName string, cmds ...string) (string, error) {
	var args = []string{"kubectl", "exec", "-n", suite.Namespace, "--kubeconfig", suite.K8sOptions.ConfigPath, podName, "--"}
	args = append(args, cmds...)
	output, err := exec.Command(args[0], args[1:]...).Output()
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
