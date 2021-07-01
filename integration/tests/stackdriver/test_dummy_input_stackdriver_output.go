// +build integration

package stackdriver

import (
	"context"
	"fmt"
	"os"
	"time"

	"github.com/calyptia/fluent-bit-ci/integration/tests"
	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/gruntwork-io/terratest/modules/terraform"

	"cloud.google.com/go/logging"
	"cloud.google.com/go/logging/logadmin"
	"google.golang.org/api/iterator"
	"google.golang.org/api/option"
)

type Suite struct {
	tests.BaseTestSuite
}

func getEntries(adminClient *logadmin.Client, projID string) ([]*logging.Entry, error) {
	ctx := context.Background()

	// [START logging_list_log_entries]
	var entries []*logging.Entry
	const name = "log-example"
	lastHour := time.Now().Add(-1 * time.Hour).Format(time.RFC3339)

	iter := adminClient.Entries(ctx,
		// Only get entries from the "log-example" log within the last hour.
		logadmin.Filter(fmt.Sprintf(`logName = "projects/%s/logs/%s" AND timestamp > "%s"`, projID, name, lastHour)),
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

func (suite *Suite) TestDummyInputToStackdriverOutput() {
	cfg, _ := suite.RenderCfgFromTpl("dummy_input_stackdriver_output", "values", nil)
	opts, _ := suite.GetTerraformOpts(cfg)

	defer terraform.Destroy(suite.T(), opts)
	terraform.InitAndApply(suite.T(), opts)

	ctx := context.Background()
	cli, err := logging.NewClient(ctx, "fluent-bit-ci",
		option.WithCredentialsJSON([]byte(os.Getenv("GCP_SA_KEY"))))
	suite.Nil(err)
	suite.NotNil(cli)

	defer cli.Close()

	admin, err := logadmin.NewClient(ctx, "fluent-bit-ci",
		option.WithCredentialsJSON([]byte(os.Getenv("GCP_SA_KEY"))))
	suite.Nil(err)
	suite.NotNil(admin)

	defer admin.Close()

	retry.DoWithRetryInterface(suite.T(), "Check to see if we get any log entries from stackdriver", tests.DefaultMaxRetries, tests.DefaultRetryTimeout, func() (interface{}, error) {
		logs, err := getEntries(admin, "integration-fluent-bit")
		if err != nil {
			return "", err
		}
		return logs, nil
	})
	//for, _ entry := range entries {
	//fmt.Printf("Entry: %6s @%s: %v\n",
	//	entry.Severity,
	//	entry.Timestamp.Format(time.RFC3339),
	//	entry.Payload)
	//}
}
