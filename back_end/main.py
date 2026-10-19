from __future__ import annotations

from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, HTTPException
from sqlalchemy.orm import Session

import models
import schemas
from database import criar_tabelas, get_db
from services.agendador import iniciar_agendador, parar_agendador
from services.alertas import lotes_vencendo
from services.fonte_venda import SaidaManual, SaidaScanner
from services.notificacao import enviar_alerta_validade

# Um adapter por origem possível. Pra adicionar uma fonte nova (ex.: API
# da Stone no futuro), cria a classe em services/fonte_venda.py e registra
# aqui — nenhum endpoint precisa mudar.
_FONTES = {
    models.OrigemMovimentacao.MANUAL: SaidaManual(),
    models.OrigemMovimentacao.SCANNER: SaidaScanner(),
}


@asynccontextmanager
async def lifespan(app: FastAPI):
    criar_tabelas()
    iniciar_agendador()
    yield
    parar_agendador()


app = FastAPI(title="Controle de Estoque com Alerta de Validade", lifespan=lifespan)


# ---------- Produtos ----------

@app.post("/produtos", response_model=schemas.ProdutoRead, status_code=201)
def criar_produto(produto: schemas.ProdutoCreate, db: Session = Depends(get_db)):
    db_produto = models.Produto(**produto.model_dump())
    db.add(db_produto)
    db.commit()
    db.refresh(db_produto)
    return db_produto


@app.get("/produtos", response_model=list[schemas.ProdutoRead])
def listar_produtos(db: Session = Depends(get_db)):
    return db.query(models.Produto).order_by(models.Produto.nome).all()


@app.get("/produtos/{produto_id}", response_model=schemas.ProdutoRead)
def obter_produto(produto_id: int, db: Session = Depends(get_db)):
    produto = db.get(models.Produto, produto_id)
    if produto is None:
        raise HTTPException(404, "Produto não encontrado")
    return produto


@app.get("/produtos/{produto_id}/lotes", response_model=list[schemas.LoteRead])
def listar_lotes_do_produto(produto_id: int, db: Session = Depends(get_db)):
    """Todos os lotes de um produto, inclusive os já zerados — é o que
    a tela de detalhe usa pra deixar apagar lote antigo."""
    produto = db.get(models.Produto, produto_id)
    if produto is None:
        raise HTTPException(404, "Produto não encontrado")
    return (
        db.query(models.Lote)
        .filter(models.Lote.produto_id == produto_id)
        .order_by(models.Lote.data_validade)
        .all()
    )


@app.delete("/produtos/{produto_id}", status_code=204)
def excluir_produto(
    produto_id: int,
    forcar: bool = False,
    db: Session = Depends(get_db),
):
    """Apaga o produto e todos os lotes dele.

    Por segurança, recusa se ainda houver estoque — o app mostra o
    aviso e só manda forcar=true depois que a pessoa confirmar.
    """
    produto = db.get(models.Produto, produto_id)
    if produto is None:
        raise HTTPException(404, "Produto não encontrado")

    em_estoque = sum(
        lote.quantidade_atual
        for lote in produto.lotes
        if lote.quantidade_atual > 0
    )

    if em_estoque > 0 and not forcar:
        raise HTTPException(
            409,
            f"Produto ainda tem {em_estoque} unidade(s) em estoque",
        )

    db.delete(produto)  # cascade apaga os lotes e movimentações
    db.commit()
    return None


# ---------- Lotes ----------

@app.post("/produtos/{produto_id}/lotes", response_model=schemas.LoteRead, status_code=201)
def criar_lote(produto_id: int, lote: schemas.LoteCreate, db: Session = Depends(get_db)):
    produto = db.get(models.Produto, produto_id)
    if produto is None:
        raise HTTPException(404, "Produto não encontrado")

    db_lote = models.Lote(produto_id=produto_id, **lote.model_dump())
    db.add(db_lote)
    db.commit()
    db.refresh(db_lote)

    # toda entrada também vira movimentação, pro histórico ficar completo
    entrada = models.MovimentacaoEstoque(
        lote_id=db_lote.id,
        tipo=models.TipoMovimentacao.ENTRADA,
        origem=models.OrigemMovimentacao.MANUAL,
        quantidade=db_lote.quantidade_atual,
    )
    db.add(entrada)
    db.commit()
    return db_lote


@app.get("/lotes", response_model=list[schemas.LoteRead])
def listar_lotes(db: Session = Depends(get_db)):
    return db.query(models.Lote).order_by(models.Lote.data_validade).all()


@app.post("/lotes/{lote_id}/saida", response_model=schemas.MovimentacaoRead)
def registrar_saida(lote_id: int, saida: schemas.SaidaRequest, db: Session = Depends(get_db)):
    fonte = _FONTES.get(saida.origem)
    if fonte is None:
        raise HTTPException(400, f"Origem '{saida.origem}' sem adapter configurado")
    try:
        return fonte.registrar_saida(db, lote_id, saida.quantidade, saida.tipo)
    except ValueError as exc:
        raise HTTPException(400, str(exc)) from exc


@app.delete("/lotes/{lote_id}", status_code=204)
def excluir_lote(lote_id: int, db: Session = Depends(get_db)):
    """Apaga o lote de vez. Use só pra corrigir cadastro errado —
    pra produto que venceu ou foi vendido, registre a SAÍDA em vez
    de excluir, senão o histórico do painel financeiro se perde."""
    lote = db.get(models.Lote, lote_id)
    if lote is None:
        raise HTTPException(404, "Lote não encontrado")
    db.delete(lote)
    db.commit()
    return None


# ---------- Alertas ----------

@app.get("/alertas/vencendo", response_model=list[schemas.LoteRead])
def alertas_vencendo(dias: int = 14, db: Session = Depends(get_db)):
    return lotes_vencendo(db, dias=dias)


@app.post("/alertas/enviar-agora")
def enviar_alerta_agora(db: Session = Depends(get_db)):
    """Dispara o e-mail de alerta na hora, sem esperar o horário agendado.
    Útil pra testar a configuração de e-mail."""
    enviou = enviar_alerta_validade(db)
    if enviou:
        return {"status": "enviado"}
    return {
        "status": "nao_enviado",
        "motivo": "e-mail não configurado ou nenhum lote vencendo",
    }
