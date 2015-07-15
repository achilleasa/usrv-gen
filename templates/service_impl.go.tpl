//go:generate protoc --go_out=. messages.proto
package {{ .PkgName }}

import "golang.org/x/net/context"

// Bootstrap the server. This method will be invoked when the service starts.
// If this method returns a non-nil error, the server will exit.
func (server *Server) init() error {
	// The current transport is available using the expression server.transport
	{{if eq .UseEtcd true}}// An etcd client instance for configuring services is available using the expression server.etcdSrv{{end}}
	return nil
}

// Process an incoming service request.
func (server *Server) handleRequest(ctx context.Context, request *Request) (*Response, error) {
	return &Response{}, nil
}
