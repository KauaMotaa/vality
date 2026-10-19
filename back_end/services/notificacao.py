"""Monta e envia o e-mail diário de alerta de validade."""

from __future__ import annotations

import logging
import smtplib
from datetime import date
from email.message import EmailMessage

from sqlalchemy.orm import Session

from config import EmailConfig
from models import Lote, Produto
from services.alertas import lotes_vencendo

logger = logging.getLogger(__name__)


def _dias_para_vencer(lote: Lote) -> int:
    return (lote.data_validade - date.today()).days


def montar_corpo(db: Session, lotes: list[Lote]) -> str:
    """Monta o HTML do e-mail com os lotes, ordenados por urgência."""
    linhas = []
    for lote in sorted(lotes, key=_dias_para_vencer):
        produto = db.get(Produto, lote.produto_id)
        nome = produto.nome if produto else f"Produto #{lote.produto_id}"
        dias = _dias_para_vencer(lote)

        if dias < 0:
            situacao = f"VENCIDO há {-dias} dia(s)"
            cor = "#c62828"
        elif dias == 0:
            situacao = "Vence HOJE"
            cor = "#e65100"
        elif dias == 1:
            situacao = "Vence amanhã"
            cor = "#e65100"
        else:
            situacao = f"Vence em {dias} dias"
            cor = "#f9a825"

        valor = ""
        if lote.preco_custo is not None:
            total = lote.quantidade_atual * float(lote.preco_custo)
            valor = f"R$ {total:.2f}".replace(".", ",")

        linhas.append(
            f'<tr>'
            f'<td style="padding:8px;border-bottom:1px solid #eee">{nome}</td>'
            f'<td style="padding:8px;border-bottom:1px solid #eee;color:{cor};'
            f'font-weight:bold">{situacao}</td>'
            f'<td style="padding:8px;border-bottom:1px solid #eee">'
            f'{lote.data_validade.strftime("%d/%m/%Y")}</td>'
            f'<td style="padding:8px;border-bottom:1px solid #eee">'
            f'{lote.quantidade_atual}</td>'
            f'<td style="padding:8px;border-bottom:1px solid #eee">{valor}</td>'
            f'</tr>'
        )

    total_risco = sum(
        lote.quantidade_atual * float(lote.preco_custo)
        for lote in lotes
        if lote.preco_custo is not None
    )

    return f"""
    <html><body style="font-family:Arial,sans-serif;color:#333">
      <h2>Alerta de validade — {date.today().strftime('%d/%m/%Y')}</h2>
      <p>{len(lotes)} lote(s) precisam de atenção nos próximos
         {EmailConfig.DIAS_ALERTA} dias.</p>
      <table style="border-collapse:collapse;width:100%">
        <tr style="background:#f5f5f5">
          <th style="padding:8px;text-align:left">Produto</th>
          <th style="padding:8px;text-align:left">Situação</th>
          <th style="padding:8px;text-align:left">Validade</th>
          <th style="padding:8px;text-align:left">Qtd</th>
          <th style="padding:8px;text-align:left">Valor</th>
        </tr>
        {''.join(linhas)}
      </table>
      <p style="margin-top:16px"><strong>Valor total em risco:
         R$ {total_risco:.2f}</strong></p>
      <p style="color:#888;font-size:12px">Enviado automaticamente pelo Vality.</p>
    </body></html>
    """.replace(f"R$ {total_risco:.2f}", f"R$ {total_risco:.2f}".replace(".", ","))


def enviar_alerta_validade(db: Session) -> bool:
    """Busca os lotes vencendo e manda o e-mail. Retorna True se enviou."""
    if not EmailConfig.configurado():
        logger.warning("E-mail não configurado — alerta não enviado.")
        return False

    lotes = lotes_vencendo(db, dias=EmailConfig.DIAS_ALERTA)
    if not lotes:
        logger.info("Nenhum lote vencendo. E-mail não enviado.")
        return False

    msg = EmailMessage()
    msg["Subject"] = f"[Vality] {len(lotes)} produto(s) vencendo"
    msg["From"] = EmailConfig.SMTP_USER
    msg["To"] = EmailConfig.DESTINATARIO
    msg.set_content(
        f"{len(lotes)} lote(s) vencendo nos próximos "
        f"{EmailConfig.DIAS_ALERTA} dias. Abra em um cliente que suporte HTML."
    )
    msg.add_alternative(montar_corpo(db, lotes), subtype="html")

    try:
        with smtplib.SMTP(EmailConfig.SMTP_HOST, EmailConfig.SMTP_PORT) as smtp:
            smtp.starttls()
            smtp.login(EmailConfig.SMTP_USER, EmailConfig.SMTP_PASSWORD)
            smtp.send_message(msg)
        logger.info("Alerta enviado para %s", EmailConfig.DESTINATARIO)
        return True
    except Exception:
        logger.exception("Falha ao enviar o e-mail de alerta")
        return False
