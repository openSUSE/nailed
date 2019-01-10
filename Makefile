SHELL := /bin/bash
all: new migrate fetch server

new:
	bundle exec bin/nailed --new

migrate:
	bundle exec bin/nailed --migrate

fetch:
	bundle exec bin/nailed --changes && \
	bundle exec bin/nailed --bugzilla

server:
	bundle exec bin/nailed --server
