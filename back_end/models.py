from __future__ import annotations

import enum
from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import ForeignKey, Numeric, String
from sqlalchemy import Enum as SAEnum
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship


class Base(DeclarativeBase):
    pass


class UnidadeMedida(str, enum.Enum):
    UNIDADE = "un"
    QUILO = "kg"
    LITRO = "l"
    CAIXA = "cx"


class TipoMovimentacao(str, enum.Enum):
    ENTRADA = "entrada"
    SAIDA_VENDA = "saida_venda"
    SAIDA_PERDA = "saida_perda"
    AJUSTE = "ajuste"


class OrigemMovimentacao(str, enum.Enum):
    MANUAL = "manual"
    SCANNER = "scanner"
    # futuro: STONE_API, DATAPRO_API — mesmo adapter (FonteDeSaida),
    # só troca a implementação. Ver services/fonte_venda.py


class Produto(Base):
    __tablename__ = "produtos"

    id: Mapped[int] = mapped_column(primary_key=True)
    nome: Mapped[str] = mapped_column(String(120))
    codigo_barras: Mapped[str | None] = mapped_column(String(64), unique=True, index=True)
    categoria: Mapped[str | None] = mapped_column(String(60))
    unidade_medida: Mapped[UnidadeMedida] = mapped_column(
        SAEnum(UnidadeMedida), default=UnidadeMedida.UNIDADE
    )
    estoque_minimo: Mapped[int] = mapped_column(default=0)
    ativo: Mapped[bool] = mapped_column(default=True)
    criado_em: Mapped[datetime] = mapped_column(default=datetime.utcnow)

    lotes: Mapped[list["Lote"]] = relationship(
        back_populates="produto", cascade="all, delete-orphan"
    )


class Lote(Base):
    """Cada entrada de mercadoria vira um lote — é o lote que carrega a
    validade, não o produto. Um mesmo produto pode ter vários lotes com
    datas de validade diferentes ao mesmo tempo (compra nova chegou antes
    da antiga acabar)."""

    __tablename__ = "lotes"

    id: Mapped[int] = mapped_column(primary_key=True)
    produto_id: Mapped[int] = mapped_column(ForeignKey("produtos.id"))
    quantidade_atual: Mapped[int] = mapped_column(default=0)
    data_entrada: Mapped[date] = mapped_column(default=date.today)
    data_validade: Mapped[date] = mapped_column()
    fornecedor: Mapped[str | None] = mapped_column(String(120))
    preco_custo: Mapped[Decimal | None] = mapped_column(Numeric(10, 2))
    criado_em: Mapped[datetime] = mapped_column(default=datetime.utcnow)

    produto: Mapped["Produto"] = relationship(back_populates="lotes")
    movimentacoes: Mapped[list["MovimentacaoEstoque"]] = relationship(
        back_populates="lote", cascade="all, delete-orphan"
    )


class MovimentacaoEstoque(Base):
    """Histórico imutável — nunca é editado, só inserido. quantidade_atual
    do lote é a soma corrente; a movimentação é o log de auditoria de como
    ela chegou lá."""

    __tablename__ = "movimentacoes_estoque"

    id: Mapped[int] = mapped_column(primary_key=True)
    lote_id: Mapped[int] = mapped_column(ForeignKey("lotes.id"))
    tipo: Mapped[TipoMovimentacao] = mapped_column(SAEnum(TipoMovimentacao))
    origem: Mapped[OrigemMovimentacao] = mapped_column(SAEnum(OrigemMovimentacao))
    quantidade: Mapped[int] = mapped_column()
    data: Mapped[datetime] = mapped_column(default=datetime.utcnow)
    observacao: Mapped[str | None] = mapped_column(String(255))

    lote: Mapped["Lote"] = relationship(back_populates="movimentacoes")
