package {{ .PkgName }}

import (
	"time"

	"github.com/achilleasa/usrv"
	"github.com/golang/protobuf/proto"
	"golang.org/x/net/context"
)

type ServerResponse struct {
	Response *Response
	Error    error
}

type Client struct {
	impl *usrv.Client
}

// Create a new client for this service using the specified transport.
func NewClient(transport usrv.Transport) *Client {
	return &Client{
		impl: usrv.NewClient(transport, serviceEndpoint),
	}
}

// Create a new request to the underlying endpoint. Returns a read-only channel that
// will emit a ServerResponse once it is received by the server.
//
// If ctx is cancelled while the request is in progress, the client will fail the
// request with ErrTimeout
func (client *Client) Request(ctx context.Context, request *Request) <-chan ServerResponse {
	return client.RequestWithTimeout(ctx, request, 0)
}

// Create a new request to the underlying endpoint with a client timeout. Returns a
// read-only channel that will emit a ServerResponse once it is received by the server.
//
// If the timeout expires or ctx is cancelled while the request is in progress, the client
// will fail the request with ErrTimeout
func (client *Client) RequestWithTimeout(ctx context.Context, request *Request, timeout time.Duration) <-chan ServerResponse {

	// Allocate a buffered channel for the response. We use a buffered channel to
	// ensure that our job queue does not block if the requester never reads from the
	// returned channel
	clientResChan := make(chan ServerResponse, 1)
	go func() {
		// serialize protobuf
		payload, err := proto.Marshal(request)
		if err != nil {
			clientResChan <- ServerResponse{
				Response: nil,
				Error:    err,
			}
			close(clientResChan)
			return
		}

		res := <-client.impl.RequestWithTimeout(ctx, &usrv.Message{Payload: payload}, timeout)

		// Unserialize and emit response
		response := &Response{}
		err = proto.Unmarshal(res.Message.Payload, response)
		if err != nil {
			response = nil
		}
		clientResChan <- ServerResponse{
			Response: response,
			Error:    err,
		}
		close(clientResChan)
	}()

	return clientResChan
}

// Shutdown the client and abort any pending requests with ErrCancelled.
// Invoking any client method after invoking Close() will result in an ErrClientClosed.
func (client *Client) Close() {
	client.impl.Close()
}
