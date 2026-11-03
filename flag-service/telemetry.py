import logging
import os
import time
from flask import g, request
from opentelemetry import trace, metrics
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.sdk._logs import LoggerProvider, LoggingHandler
from opentelemetry.sdk._logs.export import BatchLogRecordProcessor
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.exporter.otlp.proto.http.metric_exporter import OTLPMetricExporter
from opentelemetry.exporter.otlp.proto.http._log_exporter import OTLPLogExporter
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor

def setup(app):
    if not os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT"):
        return
    resource = Resource.create({})
    tp = TracerProvider(resource=resource)
    tp.add_span_processor(BatchSpanProcessor(OTLPSpanExporter()))
    trace.set_tracer_provider(tp)
    metrics.set_meter_provider(MeterProvider(resource=resource, metric_readers=[PeriodicExportingMetricReader(OTLPMetricExporter())]))
    lp = LoggerProvider(resource=resource)
    lp.add_log_record_processor(BatchLogRecordProcessor(OTLPLogExporter()))
    logging.getLogger().addHandler(LoggingHandler(logger_provider=lp))
    FlaskInstrumentor().instrument_app(app)
    RequestsInstrumentor().instrument()
    meter = metrics.get_meter("togglemaster")
    counter = meter.create_counter("togglemaster.http.requests")
    duration = meter.create_histogram("togglemaster.http.duration", unit="s")
    @app.before_request
    def start():
        g.request_start = time.monotonic()
    @app.after_request
    def finish(response):
        attrs = {"service": os.getenv("OTEL_SERVICE_NAME", "unknown"), "route": str(request.url_rule or "unmatched"), "status": response.status_code}
        counter.add(1, attrs)
        duration.record(time.monotonic() - g.request_start, attrs)
        logging.getLogger("http").info("request route=%s status=%s", attrs["route"], response.status_code)
        return response
