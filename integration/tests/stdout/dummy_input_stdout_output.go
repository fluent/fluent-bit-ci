// +build integration

package stdout

import (
	"os"
	"os/exec"
	"regexp"
	"strings"

	"github.com/calyptia/fluent-bit-ci/integration/tests"
)

type Suite struct {
	tests.BaseTestSuite
}

func init() {
	if err := tests.AddSuite(&Suite{BaseTestSuite: tests.BaseTestSuite{Name: "stdout"}}); err != nil {
		panic(err)
	}
}

func (suite *Suite) TestDummyInputToStdoutOutput() {
	assert := suite.BaseTestSuite.Assert()

	fluentbitbin, present := os.LookupEnv("FLUENT_BIT_BIN")
	if !present {
		fluentbitbin = "fluent-bit"
	}

	cmd := exec.Command(fluentbitbin,
		"-q",
		"-f", "1",
		"-i", "dummy",
		"-o", "stdout",
		"-p", "match=*",
		"-o", "exit",
		"-p", "match=*")

	out, err := cmd.Output()
	suite.Nil(err)

	lines := strings.Split(string(out), "\n")
	r := "^\\[\\d+\\] dummy\\.0: \\[\\d+\\.\\d+, \\{\\\"message\\\"\\=\\>\\\"dummy\\\"\\}\\]$"
	rx := regexp.MustCompile(r)

	for _, line := range lines {
		if line == "" {
			continue
		}
		assert.Regexp(rx, line)
	}
}
