package providers

import (
	"github.com/gruntwork-io/terratest/modules/helm"
	http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/random"

	"fmt"
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

func (suite *ElasticSearchSuite) TestVoidComponent() {
	helm.AddRepo(suite.T(), suite.helmOpts, "fluent", "https://fluent.github.io/helm-charts")
	helm.AddRepo(suite.T(), &helm.Options{}, "elastic", "https://helm.elastic.co")

	releaseNameES := fmt.Sprintf("elasticsearch-%s", strings.ToLower(random.UniqueId()))
	helm.Install(suite.T(), &helm.Options{KubectlOptions: suite.kubectlOpts, SetValues: map[string]string{"replicas": "1", "minMasterNodes": "1"}},"elastic/elasticsearch", releaseNameES) ////, SetValues: map[string]string{"replicas": "1", "minMasterNodes": "1"}},
	releaseName := fmt.Sprintf("fluent-bit-%s", strings.ToLower(random.UniqueId()))

	defer helm.Delete(suite.T(), suite.helmOpts, releaseNameES, true)
	defer helm.Delete(suite.T(), suite.helmOpts, releaseName, true)
	helm.Install(suite.T(), suite.helmOpts, "fluent/fluent-bit", releaseName)


	//pods := k8s.ListPods(suite.T(), suite.kubectlOpts, v1.ListOptions{})
	//
	//var podName string = ""
	//for _, pod := range pods {
	//	if strings.Contains(pod.Name, releaseName) {
	//		podName = pod.Name
	//		break
	//	}
	//}

	time.Sleep(3 * time.Minute)
	retries := 15
	sleep := 1 * time.Minute
	//k8s.WaitUntilPodAvailable(suite.T(), suite.kubectlOpts, podName, retries, sleep)

	// We will first open a tunnel to the pod, making sure to close it at the end of the test.
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
			fmt.Println("ALERTA TERRARISTA", statusCode, body)
			return statusCode == 200
		},
	)

}

//
//
//func TestPodDeploysContainerImageHelmTemplateEngine(t *testing.T) {
//
//	// Setup the kubectl config and context. Here we choose to use the defaults, which is:
//	// - HOME/.kube/config for the kubectl config file
//	// - Current context of the kubectl config file
//	// We also specify that we are working in the default namespace (required to get the Pod)
//	kubectlOptions := k8s.NewKubectlOptions("", "/tmp/client.config", "default")
//
//	// Setup the args. For this test, we will set the following input values:
//	// - image=nginx:1.15.8
//	// - fullnameOverride=minimal-pod-RANDOM_STRING
//	// We use a fullnameOverride so we can find the Pod later during verification
//	//podName := fmt.Sprintf("minimal-pod-%s", strings.ToLower(random.UniqueId()))
//	//options := &helm.Options{
//	//	SetValues: map[string]string{"image": "nginx:1.15.8", "fullnameOverride": podName},
//	//}
//
////image:
////repository: fluent/fluent-bit
////pullPolicy: Always
////	# tag:
//
//	//options := &helm.Options{
//	//	SetValues: map[string]map[string]string{"image": map[string]string{ "repository": "fluentbitdev/fluent-bit", "tag": "asdf"}},
//	//}
//
//	options := &helm.Options{
//		SetValues: map[string]string{
//			"image.repository": "fluentbitdev/fluent-bit",
//			"image.tag": "x86_64-master",
//		},
//		KubectlOptions: kubectlOptions,
//	}
//
//
// 	//// Run RenderTemplate to render the template and capture the output.
//	// output := helm.RenderTemplate(t, options, helmChartPath, "minimal-pod", []string{})
//	//
//	// Make sure to delete the resources at the end of the test
//	//defer k8s.KubectlDeleteFromString(t, kubectlOptions, output)
//
//	// Now use kubectl to apply the rendered template
//	//k8s.KubectlApplyFromString(t, kubectlOptions, output)
//
//	// Now that the chart is deployed, verify the deployment. This function will open a tunnel to the Pod and hit the
//	// nginx container endpoint.
//}
//
//// verifyNginxPod will open a tunnel to the Pod and hit the endpoint to verify the nginx welcome page is shown.
//func verifyNginxPod(t *testing.T, kubectlOptions *k8s.KubectlOptions, podName string) {
//	// Wait for the pod to come up. It takes some time for the Pod to start, so retry a few times.
//	retries := 15
//	sleep := 5 * time.Second
//	k8s.WaitUntilPodAvailable(t, kubectlOptions, podName, retries, sleep)
//
//	// We will first open a tunnel to the pod, making sure to close it at the end of the test.
//	tunnel := k8s.NewTunnel(kubectlOptions, k8s.ResourceTypePod, podName, 0, 80)
//	defer tunnel.Close()
//	tunnel.ForwardPort(t)
//
//	// ... and now that we have the tunnel, we will verify that we get back a 200 OK with the nginx welcome page.
//	// It takes some time for the Pod to start, so retry a few times.
//	endpoint := fmt.Sprintf("http://%s", tunnel.Endpoint())
//	http_helper.HttpGetWithRetryWithCustomValidation(
//		t,
//		endpoint,
//		nil,
//		retries,
//		sleep,
//		func(statusCode int, body string) bool {
//			return statusCode == 200 && strings.Contains(body, "Welcome to nginx")
//		},
//	)
//}