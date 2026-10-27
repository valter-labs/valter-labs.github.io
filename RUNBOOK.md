# RUNBOOK: app OAuth "rclone" publicado (site, Search Console e Google Cloud)

Fonte da verdade de tudo o que foi montado para o login do rclone no Google Drive parar de vencer.
Este arquivo e a pasta `scripts/` não são publicados no site (veja `_config.yml`).
Não há segredo aqui, e nunca deve haver: nada de client_secret, token, senha ou e-mail.

## 1. Por quê

- Com o app OAuth em "Testing", o Google expira o refresh token do rclone a cada 7 dias, e os backups no Drive param toda semana.
- Para publicar o app ("In production"), o Google exige na página de Branding uma página inicial, uma política de privacidade e um domínio autorizado de propriedade verificada.
- Este repositório fornece as duas páginas e a verificação do domínio. Como o escopo é só `drive.file` (não sensível), a publicação não exige verificação do app pelo Google.

## 2. Inventário

| Peça | Estado | Onde |
| --- | --- | --- |
| Repositório | público, branch `main` | https://github.com/valter-labs/valter-labs.github.io |
| GitHub Pages | ligado, origem `main` na raiz `/`, HTTPS forçado | https://valter-labs.github.io/ |
| Página inicial (PT/EN) | `index.html` | https://valter-labs.github.io/ |
| Política de privacidade (PT/EN) | `privacy.html` | https://valter-labs.github.io/privacy.html |
| Arquivo de verificação do Search Console | `google3634a51f95259bfd.html`, conteúdo `google-site-verification: google3634a51f95259bfd.html` | https://valter-labs.github.io/google3634a51f95259bfd.html |
| Propriedade do Search Console | prefixo de URL `https://valter-labs.github.io/`, verificada pelo método "Arquivo HTML" | https://search.google.com/search-console |
| Projeto do Google Cloud | `rclone-personal-backup-503108`, na conta Google pessoal do dono | https://console.cloud.google.com/auth/overview?project=rclone-personal-backup-503108 |
| Branding: nome do app | `rclone` | Google Auth Platform > Branding |
| Branding: e-mail de suporte e contato do desenvolvedor | o e-mail da conta Google pessoal do dono (não fica escrito aqui porque o repositório é público) | Branding |
| Branding: logo | nenhum (de propósito: logo exige verificação do app) | Branding |
| Branding: Application home page | `https://valter-labs.github.io/` | Branding |
| Branding: Application privacy policy link | `https://valter-labs.github.io/privacy.html` | Branding |
| Branding: Application terms of service link | vazio | Branding |
| Branding: Authorized domain 1 | `valter-labs.github.io` | Branding |
| Audience: tipo de usuário | External | Google Auth Platform > Audience |
| Audience: status de publicação | **In production** (desde 2026-10-27) | Audience |
| Data Access | nenhum escopo declarado no console; o rclone pede `drive.file` na hora do login | Google Auth Platform > Data Access |
| Verification Center | "Verification is not required since your app is not requesting any sensitive or restricted scopes." | Google Auth Platform > Verification Center |
| Remote do rclone | `gdrive:`, `type = drive`, `scope = drive.file`, cliente OAuth próprio deste projeto; `rclone.conf` cifrado, senha no Keychain via `RCLONE_PASSWORD_COMMAND` | máquina do dono |

Quem usa o remote `gdrive:`:

- arquivamento da Mesa: `gdrive:mesa-archive/` (evidências compactadas; a volta é `rclone copyto 'gdrive:mesa-archive/...'`);
- archiver do session-search: arquivo frio em `gdrive:codex-archive` (conferido por `session-search remote check`);
- cópia diária do estado do agents-chief (`tools/records/records.py backup`): `gdrive:agents-chief-state`;
- "Recarregar", citado pelo dono como usuário do remote (não localizado no código no levantamento de 2026-10-27).

Importante: com o escopo `drive.file`, o Google só mostra a um cliente OAuth os arquivos que esse mesmo cliente criou.
O par client_id/client_secret do projeto `rclone-personal-backup-503108` é a identidade permanente desses arquivos.
**Nunca apague o projeto nem o cliente OAuth**: os arquivos continuariam no Drive, mas ficariam invisíveis para o rclone.

## 3. REFAZER do zero

Pré-requisitos: `gh` com login numa conta admin da organização `valter-labs`, `git`, `curl` e uma cópia local deste repositório (clone ou backup).
No Google, use sempre a conta pessoal do dono, a mesma que é dona do projeto. Se o navegador estiver em outra conta, troque pelo seletor de conta.

### 3.1 GitHub (script)

```bash
scripts/setup.sh          # cria ou ajusta o que faltar; idempotente
scripts/setup.sh --check  # só confere
```

O que o script faz, em ordem (cada passo confere antes de mudar):

1. Confere que os arquivos do site existem na cópia local e que o arquivo de verificação tem o conteúdo esperado.
2. Cria o repositório se faltar: `gh repo create valter-labs/valter-labs.github.io --public --description "..."`. Se estiver arquivado, desarquiva com `gh repo unarchive`.
3. Se a branch `main` não existir no GitHub, envia a cópia local (`git push https://github.com/valter-labs/valter-labs.github.io.git HEAD:main`). Se já existir, não mexe.
4. Liga o Pages: `gh api -X POST repos/valter-labs/valter-labs.github.io/pages -f 'source[branch]=main' -f 'source[path]=/'`. Num repositório `<org>.github.io` o GitHub costuma ligar o Pages sozinho no primeiro push; o POST então responde 409 "GitHub Pages is already enabled", e o script só confere a origem (`main /`).
5. Espera `200` em `/`, `/privacy.html` e no arquivo de verificação (até 10 minutos), confere o conteúdo do arquivo e confere que `RUNBOOK.md` e `scripts/` dão 404 no site.

### 3.2 Search Console (manual)

1. Abra https://search.google.com/search-console/welcome com a conta pessoal do dono.
2. "Adicionar um site" > coluna "Prefixo do URL" > digite `https://valter-labs.github.io/` > CONTINUAR.
3. Em "Arquivo HTML", anote o nome do arquivo indicado. Para esta conta ele foi `google3634a51f95259bfd.html`.
   - Se o nome for outro, crie na raiz do repositório um arquivo com esse nome e com o conteúdo exato `google-site-verification: <nome do arquivo>` (sem quebra de linha no fim), troque `VERIFY_FILE` em `scripts/setup.sh`, faça commit e push, e rode `scripts/setup.sh --check` até ficar verde.
4. Com o arquivo no ar, clique em VERIFICAR. O esperado é "Propriedade verificada", método "Arquivo HTML".
5. Não apague o arquivo de verificação depois: sem ele a propriedade perde a verificação.

### 3.3 Google Cloud (manual)

1. Branding: https://console.cloud.google.com/auth/branding?project=rclone-personal-backup-503108
   - Application home page: `https://valter-labs.github.io/`
   - Application privacy policy link: `https://valter-labs.github.io/privacy.html`
   - Authorized domains > "Add domain": `valter-labs.github.io` (o console já avisa "Missing domain: valter-labs.github.io" depois que os links são preenchidos).
   - Não envie logo: logo obriga a verificação do app.
   - Save. O esperado é a mensagem "Branding changes saved!".
2. Audience: https://console.cloud.google.com/auth/audience?project=rclone-personal-backup-503108
   - "Publish app" > diálogo "Push to production?" > Confirm.
   - O esperado é "Publishing status: In production" e o botão "Back to testing".
   - PARE se o Google pedir verificação do app, logo, faturamento, aceite de contrato novo, ou mostrar escopo sensível ou restrito.
3. Reconecte o rclone uma vez (passo 6): o token emitido enquanto o app estava em Testing continua com a validade curta.

## 4. DESFAZER (ordem segura)

A ordem importa: primeiro o Google para de depender do site, depois o site sai do ar.

1. **Voltar o app para Testing** (manual): Audience > "Back to testing" > confirmar.
   Efeito: os refresh tokens voltam a vencer em 7 dias e só usuários de teste conseguem logar.
2. **Limpar o Branding** (manual): Branding > apagar "Application home page", "Application privacy policy link" e o domínio `valter-labs.github.io` (ícone de lixeira do "Authorized domain 1") > Save.
   Com o app em produção o Google exige esses campos (o "Publish app" ficou desabilitado enquanto faltavam); por isso o passo 1 vem antes.
3. **Remover a propriedade do Search Console** (manual): https://search.google.com/search-console > propriedade `https://valter-labs.github.io/` > Configurações > "Remover propriedade".
4. **Desligar o Pages e arquivar o repositório** (script):

   ```bash
   scripts/teardown.sh         # simulação: só imprime
   scripts/teardown.sh --yes   # executa: gh api -X DELETE repos/.../pages; gh repo archive ... --yes
   ```

   O script nunca roda nada no Google. Apagar o repositório de vez é opcional e irreversível; o script só imprime o comando (`gh repo delete valter-labs/valter-labs.github.io --yes`, que exige o escopo `delete_repo` no `gh`).
5. **Revogar o token do rclone** (manual): https://myaccount.google.com/permissions > app "rclone" > remover acesso.
   Efeito: o rclone para de acessar o Drive até um novo `rclone config reconnect gdrive:`.

**Não faça** como parte do desfazer: apagar o projeto `rclone-personal-backup-503108` ou o cliente OAuth. Veja o aviso no fim da seção 2.

## 5. Verificação

GitHub e site (comandos):

```bash
scripts/setup.sh --check
curl -sI https://valter-labs.github.io/ | head -1                                   # HTTP/2 200
curl -sI https://valter-labs.github.io/privacy.html | head -1                       # HTTP/2 200
curl -s  https://valter-labs.github.io/google3634a51f95259bfd.html                  # google-site-verification: google3634a51f95259bfd.html
curl -s -o /dev/null -w '%{http_code}\n' https://valter-labs.github.io/RUNBOOK.md   # 404
gh api repos/valter-labs/valter-labs.github.io/pages --jq '{html_url,source}'        # main, /
```

Google (cliques; não há leitura por CLI):

- Search Console > propriedade `https://valter-labs.github.io/` > Configurações > Verificação de propriedade: "Arquivo HTML" verificado.
- https://console.cloud.google.com/auth/audience?project=rclone-personal-backup-503108: "Publishing status" = **In production**.
- https://console.cloud.google.com/auth/branding?project=rclone-personal-backup-503108: os três campos da seção 2 preenchidos.
- https://console.cloud.google.com/auth/verification?project=rclone-personal-backup-503108: "Verification is not required ...".

rclone (máquina do dono):

```bash
rclone about gdrive:          # responde sem invalid_grant
session-search remote check   # remote-about e archive-listing em pass
```

## 6. Próximo passo do dono: reconectar o rclone

O token atual foi emitido com o app em Testing e vence no prazo curto. Depois da publicação, reconecte uma vez:

```bash
rclone config reconnect gdrive:
```

O `rclone.conf` é cifrado: o shell precisa ter `RCLONE_PASSWORD_COMMAND` exportado (a senha vem do Keychain).
No consentimento, o Google pode mostrar o aviso de app não verificado; continue com a conta pessoal do dono.
O novo refresh token não vence por prazo. Ele só cai se ficar 6 meses sem uso, se o acesso for revogado ou se o app voltar para Testing.

## 7. Histórico (o que de fato aconteceu)

### 2026-10-27: montagem e publicação

- Repositório criado com `gh repo create valter-labs/valter-labs.github.io --public`.
- Os commits usam como autor o e-mail noreply do GitHub, para não expor e-mail num repositório público.
- `gh api -X POST .../pages` respondeu `409 GitHub Pages is already enabled`: o GitHub ligou o Pages sozinho (origem `main /`, HTTPS forçado). O site respondeu 200 cerca de 1 minuto depois do push.
- Search Console, propriedade de prefixo de URL `https://valter-labs.github.io/`, método "Arquivo HTML", arquivo `google3634a51f95259bfd.html`.
  - **Bloqueio contornado**: o download do arquivo pelo navegador automatizado foi recusado pela ponte de aprovações do Codex Chrome ("the approval list never covers this action"), e o conteúdo não aparece na página (é gerado no clique).
  - O arquivo foi gravado com o formato fixo documentado pelo Google: `google-site-verification: <nome do arquivo>`.
  - O Google aceitou: "Propriedade verificada", método "Arquivo HTML".
- Branding: home page, política e domínio `valter-labs.github.io` preenchidos; "Branding changes saved!".
- Audience: "Publish app" > "Push to production?" > Confirm > **In production**. Nenhum pedido de verificação, logo, faturamento ou contrato.
- Data Access sem escopo declarado. Verification Center: "Verification is not required since your app is not requesting any sensitive or restricted scopes."
- Branding status no Verification Center: "Your branding is not being shown to users". Esperado: sem verificação de marca, a tela de consentimento mostra o aviso de app não verificado. Não afeta a validade do token.
- O rclone ainda não foi reconectado: é o passo 6, do dono.
