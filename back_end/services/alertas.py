from __future__ import annotations

from datetime import date, timedelta

from sqlalchemy import select
from sqlalchemy.orm import Session

from models import Lote


def lotes_vencendo(db: Session, dias: int = 7) -> list[Lote]:
    """Lotes com estoque > 0 que vencem dentro de `dias` dias (inclui
    os já vencidos). É essa lista que o job diário (cron / APScheduler)
    varre pra disparar e-mail/WhatsApp."""
    limite = date.today() + timedelta(days=dias)
    stmt = (
        select(Lote)
        .where(Lote.quantidade_atual > 0)
        .where(Lote.data_validade <= limite)
        .order_by(Lote.data_validade.asc())
    )
    return list(db.scalars(stmt))
