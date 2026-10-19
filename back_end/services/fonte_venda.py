from __future__ import annotations

from abc import ABC, abstractmethod

from sqlalchemy.orm import Session

from models import Lote, MovimentacaoEstoque, OrigemMovimentacao, TipoMovimentacao


class FonteDeSaida(ABC):
    """Interface pra qualquer jeito de dar baixa no estoque de um lote.

    Hoje: SaidaManual (formulário no sistema) e SaidaScanner (app Flutter
    lendo código de barras). Amanhã, se você conseguir acesso à API da
    Stone (Connect 2.0) ou da DataPro: cria um SaidaStoneAPI(FonteDeSaida)
    implementando o mesmo contrato, e o resto do sistema nem percebe a
    diferença — endpoints, testes e queries de alerta continuam iguais.
    """

    origem: OrigemMovimentacao

    @abstractmethod
    def registrar_saida(
        self,
        db: Session,
        lote_id: int,
        quantidade: int,
        tipo: TipoMovimentacao = TipoMovimentacao.SAIDA_VENDA,
    ) -> MovimentacaoEstoque:
        ...

    def _aplicar(
        self, db: Session, lote_id: int, quantidade: int, tipo: TipoMovimentacao
    ) -> MovimentacaoEstoque:
        lote = db.get(Lote, lote_id)
        if lote is None:
            raise ValueError(f"Lote {lote_id} não encontrado")
        if lote.quantidade_atual < quantidade:
            raise ValueError("Quantidade insuficiente no lote")

        lote.quantidade_atual -= quantidade
        mov = MovimentacaoEstoque(
            lote_id=lote_id,
            tipo=tipo,
            origem=self.origem,
            quantidade=quantidade,
        )
        db.add(mov)
        db.commit()
        db.refresh(mov)
        return mov


class SaidaManual(FonteDeSaida):
    origem = OrigemMovimentacao.MANUAL

    def registrar_saida(self, db, lote_id, quantidade, tipo=TipoMovimentacao.SAIDA_VENDA):
        return self._aplicar(db, lote_id, quantidade, tipo)


class SaidaScanner(FonteDeSaida):
    origem = OrigemMovimentacao.SCANNER

    def registrar_saida(self, db, lote_id, quantidade, tipo=TipoMovimentacao.SAIDA_VENDA):
        return self._aplicar(db, lote_id, quantidade, tipo)
