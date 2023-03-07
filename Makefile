# Use a single bash shell for each job, and immediately exit on failure
SHELL := bash
.SHELLFLAGS := -ceu
.ONESHELL:

# This doesn't work on directories.
# See https://stackoverflow.com/questions/25752543/make-delete-on-error-for-directory-targets
.DELETE_ON_ERROR:

# Don't print the commands in the file unless you specify VERBOSE. This is
# essentially the same as putting "@" at the start of each line.
ifndef VERBOSE
.SILENT:
endif

# Create the output directories if they do not exist.
$(shell mkdir -p build)

VERSION := $(shell ./scripts/version.sh)

clean:
	rm -rf build
.PHONY: clean

fmt:
	go fmt ./...
.PHONY: fmt

lint:
	golangci-lint run
.PHONY: lint

build: build/tunneld build/tunnel
.PHONY: build

# build/tunneld and build/tunnel build the Go binary for the current
# architecture. You can change the architecture by setting GOOS and GOARCH
# manually before calling this target.
build/tunneld build/tunnel: build/%: $(shell find . -type f -name '*.go')
	go build \
		-o "$@" \
		-tags urfave_cli_no_docs \
		-ldflags "-s -w -X 'github.com/coder/wgtunnel/buildinfo.tag=$(VERSION)'" \
		"./cmd/$*"

# build/tunneld.tag generates the Docker image for tunneld.
build/tunneld.tag: build/tunneld
	tag="ghcr.io/coder/wgtunnel/tunneld:$(VERSION)"

	# make a temp directory, copy the binary into it, and build the image.
	temp_dir=$$(mktemp -d)
	cp build/tunneld "$$temp_dir"

	docker build \
		--file Dockerfile \
		--build-arg "WGTUNNEL_VERSION=$(VERSION)" \
		--tag "$$tag" \
		"$$temp_dir"

	rm -rf "$$temp_dir"
	echo "$$tag" > "$@"

test:
	go clean -testcache
	gotestsum -- -v -short ./...
.PHONY: test