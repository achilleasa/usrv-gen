package {{ .PkgName }}

import (
	"log"
	{{if eq .UseThrottle true}}"time"{{end}}

	{{if eq .UseEtcd true}}"github.com/achilleasa/service-adapters/etcd"{{end}}
	"github.com/achilleasa/usrv"
	{{if eq .UseThrottle true}}usrvMiddleware "github.com/achilleasa/usrv/middleware"{{end}}
	"github.com/golang/protobuf/proto"
	"golang.org/x/net/context"
)

var (
	serviceEndpoint = "{{ .SrvEndpoint }}"
)

type Server struct {
	{{if eq .UseEtcd true}}etcdSrv   *etcd.Etcd{{end}}
	impl      *usrv.Server
	transport usrv.Transport
}

// Create a new server using the supplied transport.
func NewServer({{if eq .UseEtcd true}}etcdSrv *etcd.Etcd,{{end}} transport usrv.Transport, logger *log.Logger) (*Server, error) {
	impl, err := usrv.NewServer(transport, usrv.WithLogger(logger))
	if err != nil {
		return nil, err
	}

	server := &Server{
		impl:      impl,
		transport: transport,
		{{if eq .UseEtcd true}}etcdSrv:   etcdSrv,{{end}}
	}

	// Bind endpoint
	err = server.impl.Handle(
		serviceEndpoint,
		usrv.HandlerFunc(server.dispatchRequest),
		// extra middleware
		{{if eq .UseThrottle true}}usrvMiddleware.Throttle({{.ThrottleMaxConcurrent}}, time.Millisecond * {{.ThrottleMaxExecTime}}),{{end}}
	)
	if err != nil {
		return nil, err
	}

	// Run user-defined init method
	err = server.init()
	if err != nil {
		return nil, err
	}

	return server, nil
}

// This method is the main entry point for  requests to this service. If will automatically
// unmarshal the raw payload into the expected protobuf message, invoke the actual service implementation
// defined in service.go and then reply back to the client with the marshalled response message.
func (server *Server) dispatchRequest(ctx context.Context, rw usrv.ResponseWriter, message *usrv.Message) {
	// Unserialize request
	request := &Request{}
	err := proto.Unmarshal(message.Payload, request)
	if err != nil {
		rw.WriteError(err)
		return
	}

	// Pass to service implementation
	res, err := server.handleRequest(ctx, request)
	if err != nil {
		rw.WriteError(err)
		return
	}

	// Serialize response
	payload, err := proto.Marshal(res)
	if err != nil {
		rw.WriteError(err)
		return
	}
	rw.Write(payload)
}

// Start a go-routine and begin serving requests.
func (server *Server) Serve() <-chan error {
	errChan := make(chan error)
	go func() {
		err := server.impl.ListenAndServe()
		if err != nil {
			errChan <- err
		}
		close(errChan)
	}()

	return errChan
}

// Shutdown the server.
func (server *Server) Close() {
	server.impl.Close()
}
