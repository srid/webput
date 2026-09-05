usage() {
  echo "usage: webput publish <file.html|name.pages.dev>" >&2
  echo "       webput login" >&2
}

# Keep OAuth out of the user's wrangler login (~/.config/.wrangler).
: "${HOME:?}"
export XDG_CONFIG_HOME="${WEBPUT_CONFIG_HOME:-$HOME/.config/webput}"
mkdir -p "$XDG_CONFIG_HOME"

cmd_login() {
  # --device: no localhost callback (SSH, containers, no browser).
  # --browser=false: print the URL instead of trying to open one.
  exec wrangler login --device --browser=false \
    --scopes account:read user:read pages:write \
    "$@"
}

cmd_publish() {
  if [[ $# -ne 1 ]]; then
    usage
    echo "uploads to https://<name>.pages.dev" >&2
    exit 1
  fi

  arg=$1
  if [[ ! -e "$arg" ]]; then
    echo "webput: not found: $arg" >&2
    exit 1
  fi

  src=$(realpath -- "$arg")
  base=$(basename -- "$src")

  if [[ -d "$src" ]]; then
    if [[ "$base" != *.pages.dev ]]; then
      echo "webput: directory must be named <name>.pages.dev (got $base)" >&2
      exit 1
    fi
    name=${base%.pages.dev}
    if [[ ! -f "$src/index.html" ]]; then
      echo "webput: $base is missing index.html" >&2
      exit 1
    fi
  elif [[ -f "$src" ]]; then
    name=${base%.*}
    name=$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]')
  else
    echo "webput: not a file or directory: $arg" >&2
    exit 1
  fi

  if [[ "$name" == "index" ]]; then
    echo "webput: won't publish as index.pages.dev" >&2
    echo "put the files in a folder named <name>.pages.dev" >&2
    exit 1
  fi

  if [[ ! "$name" =~ ^[a-z]([a-z0-9-]{0,56}[a-z0-9])?$ ]]; then
    echo "webput: invalid Pages project name: $name" >&2
    echo "use lowercase letters, numbers, and hyphens (max 58)" >&2
    exit 1
  fi

  url="https://${name}.pages.dev"

  # wrangler whoami exits 0 even when logged out.
  whoami_out=$(wrangler whoami 2>&1) || true
  if [[ "$whoami_out" == *"not authenticated"* ]]; then
    echo "webput: not logged in to Cloudflare" >&2
    echo "run: webput login" >&2
    echo "(prints a URL and code; open the URL on any device)" >&2
    exit 1
  fi

  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' EXIT

  if [[ -d "$src" ]]; then
    cp -a -- "$src/." "$tmpdir/"
    rm -rf "$tmpdir/.git" "$tmpdir/.wrangler"
  else
    cp -- "$src" "$tmpdir/index.html"
  fi

  # First upload creates the project; later uploads reuse it.
  if ! create_out=$(wrangler pages project create "$name" --production-branch=main 2>&1); then
    if [[ "$create_out" != *"already exists"* && "$create_out" != *"already in use"* ]]; then
      printf '%s\n' "$create_out" >&2
      exit 1
    fi
  elif [[ "$create_out" == *"://"* && "$create_out" != *"$url"* ]]; then
    # Cloudflare suffixes a taken global name (foo-ab12.pages.dev). Do not claim $url.
    echo "webput: $url is not available" >&2
    printf '%s\n' "$create_out" >&2
    if ! del_out=$(wrangler pages project delete "$name" --yes 2>&1); then
      echo "webput: also failed to delete the project wrangler created instead:" >&2
      printf '%s\n' "$del_out" >&2
    fi
    exit 1
  fi

  # --cwd keeps a caller's wrangler.toml / git branch from turning this into a
  # preview deploy. --branch=main matches production.
  if ! deploy_out=$(
    wrangler --cwd="$tmpdir" pages deploy . \
      --project-name="$name" \
      --branch=main \
      --commit-dirty=true 2>&1
  ); then
    printf '%s\n' "$deploy_out" >&2
    exit 1
  fi

  printf '%s\n' "$deploy_out"
  if [[ "$deploy_out" != *"$url"* ]]; then
    echo "webput: expected $url but wrangler did not report that URL" >&2
    exit 1
  fi

  echo "$url"
}

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

cmd=$1
shift
case "$cmd" in
  login) cmd_login "$@" ;;
  publish) cmd_publish "$@" ;;
  *)
    usage
    exit 1
    ;;
esac
