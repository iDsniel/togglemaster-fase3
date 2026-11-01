package main

import (
	"context"
	"encoding/json"
	"github.com/felixge/httpsnoop"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/exporters/otlp/otlplog/otlploghttp"
	"go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetrichttp"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
	otellog "go.opentelemetry.io/otel/log"
	"go.opentelemetry.io/otel/metric"
	"go.opentelemetry.io/otel/propagation"
	sdklog "go.opentelemetry.io/otel/sdk/log"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/trace"
	"io"
	"log"
	"net/http"
	"os"
	"time"
)

func setupTelemetry() func() {
	otel.SetTextMapPropagator(propagation.TraceContext{})
	if os.Getenv("OTEL_EXPORTER_OTLP_ENDPOINT") == "" {
		return func() {}
	}
	c := context.Background()
	res, err := resource.New(c, resource.WithFromEnv(), resource.WithTelemetrySDK())
	if err != nil {
		log.Fatal(err)
	}
	te, err := otlptracehttp.New(c)
	if err != nil {
		log.Fatal(err)
	}
	tp := sdktrace.NewTracerProvider(sdktrace.WithResource(res), sdktrace.WithBatcher(te))
	me, err := otlpmetrichttp.New(c)
	if err != nil {
		log.Fatal(err)
	}
	mp := sdkmetric.NewMeterProvider(sdkmetric.WithResource(res), sdkmetric.WithReader(sdkmetric.NewPeriodicReader(me)))
	le, err := otlploghttp.New(c)
	if err != nil {
		log.Fatal(err)
	}
	lp := sdklog.NewLoggerProvider(sdklog.WithResource(res), sdklog.WithProcessor(sdklog.NewBatchProcessor(le)))
	log.SetOutput(io.MultiWriter(os.Stderr, telemetryLogWriter{lp.Logger("togglemaster")}))
	otel.SetTracerProvider(tp)
	otel.SetMeterProvider(mp)
	return func() {
		c, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		_ = lp.Shutdown(c)
		_ = tp.Shutdown(c)
		_ = mp.Shutdown(c)
	}
}

// Fixed routes prevent user IDs and arbitrary URLs from becoming metric labels.
func observedHandler(next http.Handler, routes ...string) http.Handler {
	requests, _ := otel.Meter("togglemaster").Int64Counter("togglemaster.http.requests")
	duration, _ := otel.Meter("togglemaster").Float64Histogram("togglemaster.http.duration", metric.WithUnit("s"))
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		route := "unmatched"
		for _, known := range routes {
			if r.URL.Path == known {
				route = known
			}
		}
		m := httpsnoop.CaptureMetrics(next, w, r)
		attrs := metric.WithAttributes(attribute.String("service", os.Getenv("OTEL_SERVICE_NAME")), attribute.String("route", route), attribute.Int("status", m.Code))
		requests.Add(r.Context(), 1, attrs)
		duration.Record(r.Context(), m.Duration.Seconds(), attrs)
		sc := trace.SpanContextFromContext(r.Context())
		line, _ := json.Marshal(map[string]interface{}{"event": "http_request", "service": os.Getenv("OTEL_SERVICE_NAME"), "route": route, "status": m.Code, "trace_id": sc.TraceID().String(), "span_id": sc.SpanID().String()})
		log.Print(string(line))
	})
	return otelhttp.NewHandler(handler, "http.request", otelhttp.WithSpanNameFormatter(func(_ string, r *http.Request) string {
		for _, known := range routes {
			if r.URL.Path == known {
				return r.Method + " " + known
			}
		}
		return "http.unmatched"
	}))
}

type telemetryLogWriter struct{ logger otellog.Logger }

func (w telemetryLogWriter) Write(p []byte) (int, error) {
	var record otellog.Record
	record.SetTimestamp(time.Now())
	record.SetBody(otellog.StringValue(string(p)))
	w.logger.Emit(context.Background(), record)
	return len(p), nil
}
