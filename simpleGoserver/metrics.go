package main

import (
	"net/http"
	"strconv"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

type metrics struct {
	requestCount *prometheus.CounterVec
}

var (
	reg           *prometheus.Registry
	exposedMetric *metrics
)

func newMetrics(reg prometheus.Registerer) *metrics {
	m := &metrics{
		requestCount: prometheus.NewCounterVec(
			prometheus.CounterOpts{
				Name: "requests_total",
				Help: "Track number of requests",
			},
			[]string{"request_method", "response_status_code", "app"},
		),
	}
	reg.MustRegister(m.requestCount)
	return m
}

func registerRequestMetrics() {
	// Create a non-global registry.
	reg = prometheus.NewRegistry()

	exposedMetric = newMetrics(reg)

	// Set values for the new created metrics.
	// m.hdFailures.With(prometheus.Labels{"device": "/dev/sda"}).Inc()

	// Expose metrics and custom registry via an HTTP server
	// using the HandleFor function. "/metrics" is the usual endpoint for that.
	http.Handle("/metrics", promhttp.HandlerFor(reg, promhttp.HandlerOpts{Registry: reg}))
	go http.ListenAndServe(":8081", nil)
}

func updateMetric(requestMethod string, responseStatusCode int) {
	exposedMetric.requestCount.With(prometheus.Labels{"request_method": requestMethod, "response_status_code": strconv.Itoa(responseStatusCode), "app": "posts-app"}).Inc()
}
