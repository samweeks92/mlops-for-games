FROM golang:1.20.3 as builder
WORKDIR /app
COPY . .
RUN go mod download && go mod tidy
RUN go build -v -o server

FROM debian:buster-slim
RUN set -x && apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    ca-certificates && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/server /app/server

EXPOSE 7777
CMD ["/app/server"]