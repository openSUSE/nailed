SHELL := /bin/bash
all: migrate fetch server

migrate:
	bundle exec bin/nailed --migrate

fetch:
	bundle exec bin/nailed --github && \
	bundle exec bin/nailed --bugzilla

server:
	bundle exec bin/nailed --server
