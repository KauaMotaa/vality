from __future__ import annotations

import os
from collections.abc import Generator

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from models import Base

# Local: SQLite em arquivo, zero configuração. Produção: exporta
# DATABASE_URL=postgresql://... e troca sem mexer em mais nada.
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./estoque.db")

connect_args = {"check_same_thread": False} if DATABASE_URL.startswith("sqlite") else {}
engine = create_engine(DATABASE_URL, connect_args=connect_args)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def criar_tabelas() -> None:
    Base.metadata.create_all(bind=engine)
