@echo off
REM ============================================================
REM  Vality - versao para o Agendador de Tarefas (sem pause).
REM  No Agendador, preencha tambem o campo "Iniciar em:" com
REM  C:\Users\Nordeste\Documents\back_end
REM ============================================================

cd /d "C:\Users\Nordeste\Documents\back_end"

python -m uvicorn main:app --host 0.0.0.0 --port 8000
