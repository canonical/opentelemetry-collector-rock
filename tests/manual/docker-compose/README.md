## Prerequisites
- spread is installed in $PATH
- rock is already packed
- `lxd init --auto` was already run
- docker isn't blocked:
  - `sudo iptables -I DOCKER-USER -i lxdbr0 -j ACCEPT`
  - `sudo iptables -I DOCKER-USER -o lxdbr0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT`


## Test
Push the packed rock to the docker daemon:
```bash
skopeo --insecure-policy copy \
  "oci-archive:0.118.0/opentelemetry-collector_0.118.0_amd64.rock" \
  "docker-daemon:otelcol-dev:0.118.0"
```

```bash
docker-compose -f tests/manual/docker-compose/docker-compose.yaml up -d
sleep 20  # scrape interval in config file is 15 sec

NUM_NODE_METRICS=$(curl -s --data-urlencode 'match[]={__name__=~"node_.+"}' localhost:9090/api/v1/series | jq -r '.data | .[] | .__name__' | wc -l)

if [ $NUM_NODE_METRICS -gt 100 ]; then
    echo "Number of 'node_' metrics pushed to prometheus by otelcol seems reasonable."
else
    echo "Number of 'node_' metrics pushed to prometheus by otelcol: $NUM_NODE_METRICS"
    exit 1
fi

docker-compose -f tests/manual/docker-compose/docker-compose.yaml down
```