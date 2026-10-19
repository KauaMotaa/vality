# Sistema de Controle de Estoque com Alerta de Validade

## Modelagem

**Produto** → cadastro fixo (nome, código de barras, categoria, unidade).
**Lote** → cada entrada de mercadoria. A validade fica no lote, não no
produto, porque o mesmo produto pode ter vários lotes com datas
diferentes ao mesmo tempo (compra nova chegou antes da antiga acabar).
**MovimentacaoEstoque** → log imutável de toda entrada/saída. Nunca é
editado, só inserido — é o histórico de auditoria de como o
`quantidade_atual` do lote chegou onde está.

## Por que não integrar direto com DataPro/Stone

Sistema fechado de terceiro (DataPro) não tem API pública auto-serviço, e
a integração real da Stone (Connect 2.0 / POS SDK) exige virar Parceiro
Stone formal — processo longo demais pra um projeto de portfólio. A saída
foi desenhar a origem da baixa de estoque como uma interface
(`FonteDeSaida`, em `services/fonte_venda.py`), com duas implementações
hoje (manual, scanner via app) e espaço pra plugar uma futura API real
sem mexer no resto do sistema.

## Como rodar

```bash
pip install -r requirements.txt
uvicorn main:app --reload
```

Abre `http://localhost:8000/docs` pra testar tudo pelo Swagger, sem
precisar de front-end ainda. O SQLite (`estoque.db`) é criado sozinho
no primeiro start.

## Endpoints

| Método | Rota | O que faz |
|---|---|---|
| POST | `/produtos` | Cadastra produto |
| GET | `/produtos` | Lista produtos |
| GET | `/produtos/{id}` | Detalhe de um produto |
| POST | `/produtos/{id}/lotes` | Registra entrada (novo lote) |
| GET | `/lotes` | Lista lotes, ordenado por validade |
| POST | `/lotes/{id}/saida` | Dá baixa no lote via `FonteDeSaida` (manual/scanner) |
| GET | `/alertas/vencendo?dias=7` | Lotes vencendo dentro de N dias |

Testado de ponta a ponta com `TestClient` (produto → lote → saída →
alerta → validação de estoque insuficiente), tudo passando.

## Próximos passos sugeridos

- `services/alertas.py` → job diário (APScheduler ou cron) que roda
  `lotes_vencendo()` e dispara e-mail/WhatsApp
- Testes E2E + CI (mesmo padrão do Sistema de Reservas)
- App Flutter com leitor de código de barras chamando `/lotes/{id}/saida`
  com `origem: scanner`
