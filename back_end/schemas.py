from __future__ import annotations

from datetime import date, datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict

from models import OrigemMovimentacao, TipoMovimentacao, UnidadeMedida


class ProdutoBase(BaseModel):
    nome: str
    codigo_barras: str | None = None
    categoria: str | None = None
    unidade_medida: UnidadeMedida = UnidadeMedida.UNIDADE
    estoque_minimo: int = 0


class ProdutoCreate(ProdutoBase):
    pass


class ProdutoRead(ProdutoBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    ativo: bool
    criado_em: datetime


class LoteBase(BaseModel):
    quantidade_atual: int
    data_validade: date
    data_entrada: date | None = None
    fornecedor: str | None = None
    preco_custo: Decimal | None = None


class LoteCreate(LoteBase):
    pass


class LoteRead(LoteBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    produto_id: int
    criado_em: datetime


class MovimentacaoRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    lote_id: int
    tipo: TipoMovimentacao
    origem: OrigemMovimentacao
    quantidade: int
    data: datetime
    observacao: str | None = None


class SaidaRequest(BaseModel):
    quantidade: int
    origem: OrigemMovimentacao = OrigemMovimentacao.MANUAL
    tipo: TipoMovimentacao = TipoMovimentacao.SAIDA_VENDA
