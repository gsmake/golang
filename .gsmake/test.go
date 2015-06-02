package tasks

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/gsdocker/gserrors"
	"github.com/gsmake/gsmake"
	"github.com/gsmake/gsmake/property"
)

// TaskTest run go test
func TaskTest(runner *gsmake.Runner, args ...string) error {
	// get compile binary path
	var suites []struct {
		Dir   string
		Flags string
	}

	err := runner.Property("golang", runner.Name(), "gsmake.golang.test", &suites)

	if err != nil {

		if property.NotFound(err) {
			return nil
		}

		return err
	}

	if len(suites) == 0 {
		return nil
	}

	gopath := runner.RootFS().DomainDir("golang")

	if err := os.Setenv("GOPATH", gopath); err != nil {
		return gserrors.Newf(err, "set GOPATH error :%s", gopath)
	}

	runner.D("set GOPATH :%s", gopath)

	packagepath, err := runner.Path("golang", runner.Name())

	if err != nil {
		return err
	}

	for _, suite := range suites {

		path := filepath.Join(packagepath, suite.Dir)

		runner.D("test dir : %s", suite)

		cmdargs := []string{"test"}

		flags := strings.Trim(suite.Flags, " ")

		if flags != "" {
			cmdargs = append(cmdargs, strings.Split(flags, " ")...)
		}

		runner.D("test args : %s", strings.Join(cmdargs, ","))

		cmd := exec.Command("go", cmdargs...)

		cmd.Dir = path

		cmd.Stderr = os.Stderr
		cmd.Stdout = os.Stdout
		cmd.Stdin = os.Stdin

		err := cmd.Run()

		if err != nil {
			return err
		}
	}

	return nil
}
