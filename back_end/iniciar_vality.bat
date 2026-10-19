@echo off
REM ============================================================
REM  Vality - inicia o servidor do sistema de estoque
REM  Use este para rodar na mao e enxergar mensagens de erro.
REM ============================================================

cd /d "C:\Users\Nordeste\Documents\back_end"

python -m uvicorn main:app --host 0.0.0.0 --port 8000

REM Se cair, a janela fica aberta pra dar pra ler o erro.
pause
