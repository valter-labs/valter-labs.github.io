#!/usr/bin/env bash
# Recria (ou só confere) a parte GitHub do site do app OAuth "rclone":
# o repositório público valter-labs/valter-labs.github.io e o GitHub Pages.
#
# Idempotente: cada passo confere o estado antes de mudar algo, então rodar
# de novo não estraga nada. Não lê nem grava segredo. Não toca no Google:
# os passos do Search Console e do Google Cloud são manuais (RUNBOOK.md).
#
# Uso (a partir de uma cópia local deste repositório):
#   scripts/setup.sh           cria ou ajusta o que faltar e confere o site no ar
#   scripts/setup.sh --check   só confere; não muda nada
set -euo pipefail

ORG="valter-labs"
REPO="$ORG/$ORG.github.io"
SITE="https://$ORG.github.io"
VERIFY_FILE="google3634a51f95259bfd.html"
VERIFY_BODY="google-site-verification: $VERIFY_FILE"
SITE_FILES=(index.html privacy.html "$VERIFY_FILE" _config.yml)
DESCRIPTION="Personal Google Drive backup tool (rclone) - home page and privacy policy"
WAIT_SECONDS=600

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

CHECK_ONLY=0
case "${1:-}" in
  --check) CHECK_ONLY=1 ;;
  "") ;;
  *) echo "uso: $0 [--check]" >&2; exit 2 ;;
esac

say() { printf '%s\n' "$*"; }
fail() { printf 'ERRO: %s\n' "$*" >&2; exit 1; }

for cmd in gh git curl; do
  command -v "$cmd" >/dev/null || fail "falta o comando '$cmd'"
done
gh auth status >/dev/null 2>&1 || fail "o gh está sem login; rode 'gh auth login'"

# 1. Os arquivos do site existem na cópia local.
for f in "${SITE_FILES[@]}"; do
  [ -f "$ROOT/$f" ] || fail "falta '$f' em $ROOT"
done
[ "$(cat "$ROOT/$VERIFY_FILE")" = "$VERIFY_BODY" ] \
  || fail "$VERIFY_FILE não tem o conteúdo esperado ('$VERIFY_BODY')"
say "ok   arquivos locais: ${SITE_FILES[*]}"

# 2. O repositório existe, é público e não está arquivado.
if gh repo view "$REPO" --json name >/dev/null 2>&1; then
  visibility="$(gh repo view "$REPO" --json visibility --jq .visibility)"
  archived="$(gh repo view "$REPO" --json isArchived --jq .isArchived)"
  [ "$visibility" = "PUBLIC" ] || fail "$REPO está $visibility; o Pages gratuito exige repositório público"
  if [ "$archived" = "true" ]; then
    [ "$CHECK_ONLY" = 1 ] && fail "$REPO está arquivado (rode sem --check para desarquivar)"
    say "fix  desarquivando $REPO"
    gh repo unarchive "$REPO" --yes
  fi
  say "ok   repositório $REPO (público)"
else
  [ "$CHECK_ONLY" = 1 ] && fail "$REPO não existe"
  say "fix  criando $REPO (público)"
  gh repo create "$REPO" --public --description "$DESCRIPTION"
fi

# 3. A branch main existe no GitHub. Só empurra quando ela não existe, para
#    nunca sobrescrever histórico remoto.
if git ls-remote --exit-code --heads "https://github.com/$REPO.git" main >/dev/null 2>&1; then
  say "ok   branch main no GitHub"
else
  [ "$CHECK_ONLY" = 1 ] && fail "a branch main não existe em $REPO"
  say "fix  enviando a cópia local para main"
  git -C "$ROOT" push "https://github.com/$REPO.git" HEAD:main
fi

# 4. O GitHub Pages está ligado, servindo main na raiz.
#    Num repositório <org>.github.io o GitHub costuma ligar o Pages sozinho
#    no primeiro push; aí o POST responde 409 "already enabled".
if pages="$(gh api "repos/$REPO/pages" --jq '"\(.source.branch) \(.source.path)"' 2>/dev/null)"; then
  if [ "$pages" = "main /" ]; then
    say "ok   Pages ligado (main /)"
  else
    [ "$CHECK_ONLY" = 1 ] && fail "Pages serve '$pages', esperado 'main /'"
    say "fix  ajustando a origem do Pages para main /"
    gh api -X PUT "repos/$REPO/pages" -f 'source[branch]=main' -f 'source[path]=/' >/dev/null
  fi
else
  [ "$CHECK_ONLY" = 1 ] && fail "Pages desligado em $REPO"
  say "fix  ligando o Pages (main /)"
  gh api -X POST "repos/$REPO/pages" -f 'source[branch]=main' -f 'source[path]=/' >/dev/null
fi

# 5. O site responde. Na primeira publicação leva alguns minutos.
code_of() { curl -s -o /dev/null -w '%{http_code}' "$1" || true; }
wait_200() {
  local url="$1" waited=0
  until [ "$(code_of "$url")" = "200" ]; do
    [ "$waited" -ge "$WAIT_SECONDS" ] && fail "$url não respondeu 200 em ${WAIT_SECONDS}s"
    sleep 10; waited=$((waited + 10))
  done
  say "ok   200 $url"
}
wait_200 "$SITE/"
wait_200 "$SITE/privacy.html"
wait_200 "$SITE/$VERIFY_FILE"
[ "$(curl -s "$SITE/$VERIFY_FILE")" = "$VERIFY_BODY" ] \
  || fail "$SITE/$VERIFY_FILE está no ar com conteúdo diferente do esperado"
say "ok   conteúdo de $VERIFY_FILE confere"

# O runbook e os scripts não podem estar publicados.
for path in RUNBOOK.md RUNBOOK.html scripts/setup.sh; do
  code="$(code_of "$SITE/$path")"
  [ "$code" = "404" ] || fail "$SITE/$path respondeu $code; devia ser 404 (veja _config.yml)"
done
say "ok   RUNBOOK e scripts fora do site (404)"

say ""
say "Parte GitHub pronta. Os passos do Google são manuais; veja RUNBOOK.md:"
say "  - Search Console: propriedade $SITE/ verificada por arquivo HTML"
say "  - Google Cloud: Branding (links e domínio) e Audience = In production"
