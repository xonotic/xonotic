#!/bin/sh

echo 19 | tee /proc/$$/autogroup || true
renice 19 $$

set -ex
for q in nq dq nr n dr d; do
	QUERY_STRING=$q sh build-index.sh | tail -n +3 > index-$q.html.new
	mv index-$q.html.new index-$q.html
done
ln -snf index-d.html index.html
