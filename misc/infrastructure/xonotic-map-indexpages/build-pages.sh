#!/bin/sh

echo 10 | tee /proc/$$/autogroup || true
renice 10 $$

set -ex
for q in nq dq nr n dr d; do
	QUERY_STRING=$q sh build-index.sh | tail -n +3 > index-$q.html.new
	mv index-$q.html.new index-$q.html
done
ln -snf index-d.html index.html
