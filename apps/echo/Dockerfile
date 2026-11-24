# Build a static binary, ship it on distroless as a non-root user.
FROM golang:1.27-alpine AS build
WORKDIR /src
COPY go.mod ./
COPY *.go ./
RUN go test ./... && CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /echo .

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /echo /echo
USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["/echo"]
CMD ["serve"]
