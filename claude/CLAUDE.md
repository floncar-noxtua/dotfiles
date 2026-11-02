## Code search

- Use `ast-grep` (binary `ast-grep`, not `sg`) for structural queries: calls with a given argument shape, decorators, class or function definitions, imports, and refactors across files. Example: `ast-grep run -l python -p 'logger.info($MSG)' src/`.
- Use plain grep or glob for text, strings, comments, config and file names.
- Prefer `ast-grep run -p ... -r ... --update-all` for mechanical rewrites over many files, then review the diff.

## Elasticsearch

- Use `es` (`~/dotfiles/bin/es`) for every Elasticsearch call - not raw `curl` or an MCP server. Run `es` with no arguments for usage. It targets the test cluster (`$ES_TEST_URL`, default `https://es-main.test.noxtua.dev`) and authenticates with `$ES_TEST_API_KEY`, which is a read-only key.
- Never put the key on a command line, and never read or print it. If `es` reports it unset, tell me.
- `es` refuses writes; do not work around that. Pipe large responses through `jq` or `head`.

## OTC object storage

- Use the raw `obsutil` binary at `/Users/fran/Code/obsutil_darwin_amd64_5.8.3/obsutil` for every `obs://` operation - not `obsket`, `aws` or `obsutil config`. Pass credentials inline on each command:
  `obsutil ls obs://<bucket>/<prefix>/ -d -limit=10 -e=https://obs.eu-de.otc.t-systems.com -i="$OBS_<BUCKET>_ACCESS_KEY_ID" -k="$OBS_<BUCKET>_SECRET_ACCESS_KEY"`
  `-d` lists only the folders directly under the prefix (without it, `ls` walks every object); `-limit=N` caps the listing.
- The endpoint is always `https://obs.eu-de.otc.t-systems.com`. `<BUCKET>` is the bucket name upper-cased with hyphens (and dots) turned into underscores: `data-ai-internal` -> `OBS_DATA_AI_INTERNAL_ACCESS_KEY_ID`.
- Before running, check both env vars are set without printing their values. If one is missing, tell me which one - do not guess or fall back to another bucket's keys.
- Only copy from source buckets - never write, move or delete unless I ask.
