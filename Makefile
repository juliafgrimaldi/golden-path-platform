.PHONY: up down validate render smoke

up:        ## Create the kind cluster and bootstrap the platform
	./bootstrap/up.sh

down:      ## Delete the kind cluster
	./bootstrap/down.sh

validate:  ## Check every tenants/*/tenant.yaml
	python3 scripts/validate_tenants.py

render:    ## Render all manifests into out/
	./scripts/render.sh

smoke:     ## End-to-end checks against the running cluster
	./bootstrap/smoke-test.sh
