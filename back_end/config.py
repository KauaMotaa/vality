"""Configurações de notificação, lidas de variáveis de ambiente.

NUNCA coloque senha direto no código — se um dia isso for pro GitHub,
a senha vai junto. Crie um arquivo .env (que o .gitignore ignora) ou
defina as variáveis no ambiente antes de subir o servidor.
"""

from __future__ import annotations

import os


class EmailConfig:
    # Servidor SMTP. Para Gmail: smtp.gmail.com / porta 587
    SMTP_HOST = os.getenv("SMTP_HOST", "smtp.gmail.com")
    SMTP_PORT = int(os.getenv("SMTP_PORT", "587"))

    # Conta que ENVIA o e-mail
    SMTP_USER = os.getenv("SMTP_USER", "")
    # No Gmail isso NÃO é a senha da conta: é uma "Senha de app" de 16
    # caracteres, gerada nas configurações de segurança da conta Google.
    SMTP_PASSWORD = os.getenv("SMTP_PASSWORD", "")

    # Quem RECEBE o alerta (pode ser o mesmo e-mail que envia)
    DESTINATARIO = os.getenv("EMAIL_DESTINATARIO", "")

    # Janela de dias considerada no alerta
    DIAS_ALERTA = int(os.getenv("DIAS_ALERTA", "7"))

    # Horário do disparo diário (24h)
    HORA_DISPARO = int(os.getenv("HORA_DISPARO", "8"))
    MINUTO_DISPARO = int(os.getenv("MINUTO_DISPARO", "0"))

    @classmethod
    def configurado(cls) -> bool:
        """Se não estiver tudo preenchido, o job não tenta enviar nada."""
        return bool(cls.SMTP_USER and cls.SMTP_PASSWORD and cls.DESTINATARIO)
