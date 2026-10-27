#!/usr/bin/env bash
# Desfaz a parte GitHub do site do app OAuth "rclone": desliga o GitHub Pages
# e arquiva o repositório valter-labs/valter-labs.github.io.
#
# Por padrão SÓ IMPRIME o que faria. Executa apenas com --yes.
# Nunca roda nada no Google: os passos do Google (voltar o app para Testing,
# limpar o Branding, remover a propriedade do Search Console, revogar o token)
# são manuais e vêm ANTES deste script. Veja RUNBOOK.md, seção DESFAZER.
#
# Uso:
#   scripts/teardown.sh         simulação: mostra os comandos, não muda nada
#   scripts/teardown.sh --yes   executa os comandos do GitHub
set -euo pipefail

ORG="valter-labs"
REPO="$ORG/$ORG.github.io"

YES=0
case "${1:-}" in
  --yes) YES=1 ;;
  "") ;;
  *) echo "uso: $0 [--yes]" >&2; exit 2 ;;
esac

say() { printf '%s\n' "$*"; }
run() {
  if [ "$YES" = 1 ]; then
    printf '+ %s\n' "$*"
    "$@"
  else
    printf '[simulação] %s\n' "$*"
  fi
}

command -v gh >/dev/null || { echo "ERRO: falta o comando 'gh'" >&2; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "ERRO: o gh está sem login" >&2; exit 1; }

say "ANTES deste script, faça à mão os passos 1 a 3 do DESFAZER no RUNBOOK.md:"
say "  1. Google Cloud > Audience: 'Back to testing' (os tokens voltam a vencer em 7 dias)"
say "  2. Google Cloud > Branding: apagar home page, política e o domínio autorizado; Save"
say "  3. Search Console: remover a propriedade https://$ORG.github.io/"
say ""

if ! gh repo view "$REPO" --json name >/dev/null 2>&1; then
  say "Repositório $REPO não existe; nada a fazer no GitHub."
else
  # 4a. Desligar o Pages (o site sai do ar; o Google deixa de achar o arquivo de verificação).
  if gh api "repos/$REPO/pages" >/dev/null 2>&1; then
    run gh api -X DELETE "repos/$REPO/pages"
  else
    say "Pages já está desligado em $REPO."
  fi

  # 4b. Arquivar (reversível com 'gh repo unarchive'). O histórico fica guardado.
  if [ "$(gh repo view "$REPO" --json isArchived --jq .isArchived)" = "true" ]; then
    say "Repositório $REPO já está arquivado."
  else
    run gh repo archive "$REPO" --yes
  fi
fi

say ""
say "Opcional e IRREVERSÍVEL (este script não executa; precisa do escopo delete_repo no gh):"
say "  gh repo delete $REPO --yes"
say ""
say "Depois, à mão:"
say "  5. Revogar o acesso do app 'rclone' em https://myaccount.google.com/permissions"
say "     (o rclone para de acessar o Drive até um novo 'rclone config reconnect gdrive:')."
say "NÃO apague o projeto rclone-personal-backup-503108 nem o cliente OAuth: com o escopo"
say "drive.file, só esse cliente enxerga os arquivos que ele criou no Drive."
[ "$YES" = 1 ] || say ""
[ "$YES" = 1 ] || say "Nada foi alterado (simulação). Para executar: $0 --yes"
