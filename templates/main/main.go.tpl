package main

import (
	"log"
	"os"
	"os/signal"

	"flag"
	{{if eq .UseTracer true}}"time"{{end}}

	"github.com/achilleasa/usrv-service-adapters"
	{{if eq .UseEtcd true}}"github.com/achilleasa/usrv-service-adapters/etcd"{{end}}
	{{if eq .UseTracer true}}"github.com/achilleasa/usrv-tracer"
    tracerStorage "github.com/achilleasa/usrv-tracer/storage"
    "github.com/achilleasa/usrv-service-adapters/service/redis"{{end}}
	"github.com/achilleasa/usrv-service-adapters/service/amqp"
	"github.com/achilleasa/usrv/transport"
	srv "{{ .SrvPath }}"
)

var (
	logger              = log.New(os.Stdout, "[{{ .SrvName }}] ", log.LstdFlags)
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

{{if eq .UseTracer true}}
func getTraceCollector(logger *log.Logger{{if eq .UseEtcd true}}, etcdSrv *etcd.Etcd{{end}}) (*tracer.Collector, error) {
	backend, err := redis.New(
		adapters.Logger(logger),
		{{if eq .UseEtcd true}}etcd.Config(etcdSrv, "/config/service/redis"),{{end}}
	)
	if err != nil {
		return nil, err
	}

	// Setup collector
	return tracer.NewCollector(
		tracerStorage.NewRedis(backend),
		{{ .TracerQueueSize }},
		{{ .TracerTTL }} * time.Second,
	), nil
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

	{{if eq .UseTracer true}}// Init trace collector
	collector, err := getTraceCollector(logger{{if eq .UseEtcd true}}, etcdSrv{{end}})
	if err != nil {
		logger.Fatal(err)
	}
	defer collector.Storage.Close(){{end}}

	// Create server
	server, err := {{ .PkgName }}.NewServer({{if eq .UseEtcd true}}etcdSrv, {{end}}{{if eq .UseTracer true}} collector,{{end}}transportSrv, logger)
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
