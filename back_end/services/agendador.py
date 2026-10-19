"""Agendador do job diário de alerta de validade.

Roda dentro do próprio FastAPI (APScheduler em background), então não
precisa de cron nem de outro processo: subiu o servidor, o job está de pé.
"""

from __future__ import annotations

import logging

from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.cron import CronTrigger

from config import EmailConfig
from database import SessionLocal
from services.notificacao import enviar_alerta_validade

logger = logging.getLogger(__name__)
_scheduler: BackgroundScheduler | None = None


def _rodar_job() -> None:
    db = SessionLocal()
    try:
        enviar_alerta_validade(db)
    finally:
        db.close()


def iniciar_agendador() -> None:
    global _scheduler
    if _scheduler is not None:
        return

    _scheduler = BackgroundScheduler(timezone="America/Sao_Paulo")
    _scheduler.add_job(
        _rodar_job,
        trigger=CronTrigger(
            hour=EmailConfig.HORA_DISPARO,
            minute=EmailConfig.MINUTO_DISPARO,
        ),
        id="alerta_validade_diario",
        replace_existing=True,
    )
    _scheduler.start()
    logger.info(
        "Agendador ativo — alerta diário às %02d:%02d",
        EmailConfig.HORA_DISPARO,
        EmailConfig.MINUTO_DISPARO,
    )


def parar_agendador() -> None:
    global _scheduler
    if _scheduler is not None:
        _scheduler.shutdown(wait=False)
        _scheduler = None
