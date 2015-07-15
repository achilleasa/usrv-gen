package main

import (
	"log"
	"os"
	"os/signal"

	"flag"

	"github.com/achilleasa/service-adapters"
	"github.com/achilleasa/service-adapters/etcd"
	"github.com/achilleasa/service-adapters/service/amqp"
	"github.com/achilleasa/usrv/transport"
	"golang.org/x/net/context"
)

var (
	logger              = log.New(os.Stdout, "[foo] ", log.LstdFlags)
	etcdHosts           = flag.String("etcd-hosts", "http://127.0.0.1:4001", "A comma delimited list of etcd hosts for automatic service configuration")
	logAll              = flag.Bool("log-all", false, "Log all messages")
	logTransport        = flag.Bool("log-transport", false, "Log transport messages")
	logServer           = flag.Bool("log-server", false, "Log server messages")
	logTransportBackend = flag.Bool("log-transport-backend", false, "Log transport backend messages")
)

{{if eq .UseEtcd true}}
func getEtcd() *etcd.Etcd {
	// Check for env var override
	envVal := os.Getenv("ETCD_HOSTS")
	if envVal != "" {
		logger.Printf("[MAIN] Found ETCD_HOSTS env var; using etcd hosts = %s\n", envVal)
		return etcd.New(envVal)
	}

	// Init etcd client
	logger.Printf("[MAIN] using etcd hosts = %s\n", *etcdHosts)
	return etcd.New(*etcdHosts)
}{{end}}

func main() {
	// Parse command line args
	flag.Parse()
	if *logAll {
		*logTransport = true
		*logTransportBackend = true
		*logServer = true
	}

	{{if eq .UseEtcd true}}// Init etcd client
	etcdSrv := getEtcd(){{end}}

	// Setup transport backend
	backend, err := amqp.New(
		adapters.Logger(logger),
		{{if eq .UseEtcd true}}etcd.Config(etcdSrv, "/config/service/amqp"),{{end}}
	)
	if err != nil {
		logger.Fatal(err)
	}
	defer backend.Close()

	// Setup transport
	transportSrv := transport.NewAmqp(backend)
	transportSrv.SetLogger(logger)
	defer transportSrv.Close()

	// Create server
	server, err := {{ .PkgName }}.NewServer({{if eq .UseEtcd true}}etcdSrv, {{end}}transportSrv, logger)
	defer server.Close()

	// Register signal handler and block until we receive a signal or a server error
	sigChan := make(chan os.Signal)
	signal.Notify(sigChan, os.Interrupt)
	errChan := server.Serve()

	select {
	case <-sigChan:
		logger.Printf("[MAIN] Received SIGINT; shutting down\n")
	case err = <-errChan:
		logger.Fatalf("[MAIN] Caught: %v", err)
	}
}
