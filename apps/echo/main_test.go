package main

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestCallReachesHandler(t *testing.T) {
	srv := httptest.NewServer(handler())
	defer srv.Close()

	body, err := call(srv.URL, time.Second)
	if err != nil {
		t.Fatalf("call: %v", err)
	}
	if body != "ok\n" {
		t.Fatalf("body = %q, want %q", body, "ok\n")
	}
}

func TestCallFailsOnNon200(t *testing.T) {
	srv := httptest.NewServer(http.NotFoundHandler())
	defer srv.Close()

	if _, err := call(srv.URL, time.Second); err == nil {
		t.Fatal("expected an error for a 404")
	}
}

func TestCallFailsWhenUnreachable(t *testing.T) {
	srv := httptest.NewServer(handler())
	url := srv.URL
	srv.Close() // nothing listens there any more, like a port blocked by policy

	if _, err := call(url, 500*time.Millisecond); err == nil {
		t.Fatal("expected an error for an unreachable server")
	}
}
