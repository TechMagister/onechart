
.PHONY: all lint kubeconform test debug debug-ui

all: lint kubeconform test

lint:
	helm lint charts/onechart/
	helm lint charts/cron-job/
	helm lint charts/static-site

kubeconform:
	rm -rf manifests && true
	mkdir manifests
	helm template charts/onechart --output-dir manifests
	kubeconform -ignore-missing-schemas -kubernetes-version 1.20.0 manifests
	kubeconform -ignore-missing-schemas -kubernetes-version 1.24.0 manifests

	rm -rf manifests && true
	mkdir manifests
	helm template charts/cron-job --output-dir manifests
	kubeconform -ignore-missing-schemas -kubernetes-version 1.20.0 manifests
	kubeconform -ignore-missing-schemas -kubernetes-version 1.24.0 manifests

	rm -rf manifests && true
	mkdir manifests
	helm template charts/static-site --output-dir manifests
	kubeconform -ignore-missing-schemas -kubernetes-version 1.20.0 manifests
	kubeconform -ignore-missing-schemas -kubernetes-version 1.24.0 manifests

test:
	helm dependency update charts/onechart
	helm unittest charts/onechart

	helm dependency update charts/cron-job
	helm unittest charts/cron-job

	helm dependency update charts/static-site
	helm unittest charts/static-site

debug:
	helm dependency update charts/onechart
	helm template my-release charts/onechart/ -f values.yaml --debug

debug-cron-job:
	helm dependency update charts/cron-job
	helm template charts/cron-job/ -f values-cron-job.yaml --debug
