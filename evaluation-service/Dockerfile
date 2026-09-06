# syntax=docker/dockerfile:1
FROM golang:1.21-alpine AS builder
WORKDIR /app
RUN apk add --no-cache git ca-certificates
COPY go.* ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/service .

FROM alpine:3.20
RUN addgroup -S app && adduser -S app -G app && apk add --no-cache ca-certificates curl
WORKDIR /app
COPY --from=builder /out/service /app/service
USER app
EXPOSE 8000
ENTRYPOINT ["/app/service"]
