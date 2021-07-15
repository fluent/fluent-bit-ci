// +build integration

package stackdriver

import (
	"context"
	"fmt"
	"math/rand"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/calyptia/fluent-bit-ci/integration/tests"
	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/gruntwork-io/terratest/modules/terraform"

	"cloud.google.com/go/logging"
	"cloud.google.com/go/logging/logadmin"
	"google.golang.org/api/iterator"
	"google.golang.org/api/option"

	"github.com/flosch/pongo2/v4"
	"github.com/stretchr/testify/suite"
	"google.golang.org/protobuf/types/known/structpb"
)

type Suite struct {
	tests.BaseTestSuite
}

func getEntries(adminClient *logadmin.Client, projID, name string) ([]*logging.Entry, error) {
	ctx := context.Background()

	// [START logging_list_log_entries]
	var entries []*logging.Entry
	lastHour := time.Now().Add(-1 * time.Hour).Format(time.RFC3339)

	iter := adminClient.Entries(ctx,
		// Only get entries from the "log-example" log within the last hour.
		logadmin.Filter(fmt.Sprintf(`logName = "projects/%s/logs/%s" AND timestamp > "%s"`,
			projID, name, lastHour)),
		// Get most recent entries first.
		logadmin.NewestFirst(),
	)

	// Fetch the most recent 20 entries.
	for len(entries) < 20 {
		entry, err := iter.Next()
		if err == iterator.Done {
			return entries, nil
		}
		if err != nil {
			return nil, err
		}
		entries = append(entries, entry)
	}
	return entries, nil
	// [END logging_list_log_entries]
}

func TestSuite(t *testing.T) {
	s := &Suite{BaseTestSuite: tests.BaseTestSuite{Name: "stackdriver"}}
	suite.Run(t, s)
}

func (s *Suite) TestDummyInputToStackdriverOutput() {
	// create a unique log id to use as a tag for filtering
	random := fmt.Sprintf("%d", rand.Int())
	logid := strings.Join([]string{"dummy", random}, "-")

	cfg, _ := s.RenderCfgFromTpl("dummy_input_stackdriver_output", "values", pongo2.Context{
		"logid": logid,
	})
	opts, _ := s.GetTerraformOpts(cfg)

	defer terraform.Destroy(s.T(), opts)
	terraform.InitAndApply(s.T(), opts)

	ctx := context.Background()
	cli, err := logging.NewClient(ctx, "fluent-bit-ci",
		option.WithCredentialsJSON([]byte(os.Getenv("GCP_SA_KEY"))))
	s.Nil(err)
	s.NotNil(cli)

	defer cli.Close()

	admin, err := logadmin.NewClient(ctx, "fluent-bit-ci",
		option.WithCredentialsJSON([]byte(os.Getenv("GCP_SA_KEY"))))
	s.Nil(err)
	s.NotNil(admin)

	defer admin.Close()

	logs := retry.DoWithRetryInterface(s.T(), "Check to see if we get any log entries from stackdriver", tests.DefaultMaxRetries, tests.DefaultRetryTimeout, func() (interface{}, error) {
		logs, err := getEntries(admin, "fluent-bit-ci", logid)
		if err != nil {
			return nil, err
		}
		if len(logs) <= 0 {
			return nil, fmt.Errorf("empty logs")
		}
		return logs, nil
	})

	assert := s.Assert()
	assert.NotEmpty(logs)
	for _, log := range logs.([]*logging.Entry) {
		val, ok := log.Payload.(*structpb.Struct)
		assert.True(ok)
		json, err := val.MarshalJSON()
		assert.Nil(err)
		assert.Equal(`{"message":"testing"}`, string(json))
	}
}
