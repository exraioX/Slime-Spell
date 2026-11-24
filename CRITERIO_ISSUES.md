# Critério de Criação de Issues — Slime-Spell

Repositório: exraioX/Slime-Spell (branch de trabalho: `testes`)

## Quando criar uma issue

Crie uma issue quando houver pelo menos um dos seguintes:
- Bug reproduzível ou comportamento inesperado.
- Funcionalidade nova ou alteração de escopo.
- Tarefa de teste/QA para um módulo.
- Documentação faltante ou desatualizada.
- Débito técnico que impacta entrega.

Não crie issue para:
- Ajustes triviais de formatação sem impacto.
- Dúvidas resolvidas em conversa.
- Trabalho já coberto por issue aberta.

## Formato do título

`[TIPO] descrição curta e objetiva`

Tipos permitidos: `BUG`, `FEAT`, `TESTE`, `DOC`, `CHORE`.

## Labels obrigatórias

Toda issue deve ter ao menos uma label de tipo (`bug`, `feature`, `teste`, `doc`, `chore`) e uma de área (`player`, `menu`, `minigame`, `audio`, `dialogo`, `cena`, `infra`).

## Corpo da issue

- Contexto/objetivo.
- Passos para reproduzir (se BUG) ou critérios de aceite (se FEAT/TESTE).
- Arquivos/módulos afetados.
- Prioridade: baixa / média / alta.

## Fluxo

1. Criar issue no GitHub com título e corpo seguindo o formato.
2. Associar à branch `testes` quando for trabalho de QA.
3. Fechar apenas com evidência (commit/PR ou teste passando).
