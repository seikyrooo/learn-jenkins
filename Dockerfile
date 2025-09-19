FROM golang:1.22 AS builder
WORKDIR /src
ENV GO111MODULE=off CGO_ENABLED=0 GOOS=linux GOARCH=amd64
COPY . .
RUN go build -o app ./cmd/server   # pastikan tidak ada import eksternal

FROM gcr.io/distroless/base-debian12
WORKDIR /app
COPY --from=builder /src/app /app/app
EXPOSE 8050
ENTRYPOINT ["/app/app"]