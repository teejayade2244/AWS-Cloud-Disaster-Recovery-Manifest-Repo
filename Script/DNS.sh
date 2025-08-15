#!/bin/bash

echo "=== DNS Resolution Check ==="
echo "Current IPs for app.coreservetest.co.uk:"
dig +short app.coreservetest.co.uk

echo -e "\n=== Compare with Direct ALB IPs ==="
echo "Primary ALB (eu-west-2):"
dig +short k8s-auraflow-reactfro-6cd6adc8a3-1847505482.eu-west-2.elb.amazonaws.com

echo "Secondary ALB (us-east-1):"
dig +short k8s-auraflow-reactfro-c198b24cd0-2127302160.us-east-1.elb.amazonaws.com

echo -e "\n=== HTTP Response Headers Check ==="
echo "Checking headers from your app:"
curl -I http://app.coreservetest.co.uk

echo -e "\n=== AWS CLI Health Check Status ==="
echo "Route 53 Health Check Status:"
aws route53 list-health-checks \
  --query 'HealthChecks[?Tags[?Key==`Name` && contains(Value, `aura-flow`)]].[Id,CallerReference]' \
  --output table

echo -e "\n=== Geolocation Check ==="
echo "Using external service to identify server location:"
curl -s "http://ip-api.com/json/$(dig +short app.coreservetest.co.uk | head -1)" | jq '.country, .regionName, .city'