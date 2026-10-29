"""
Executa o pipeline completo do Radar de Voz do Consumidor, em ordem.
Uso:  python run_all.py
"""
import runpy
from pathlib import Path

AQUI = Path(__file__).resolve().parent
ETAPAS = ["1_ingestao.py", "2_treino.py", "3_classifica.py",
          "4_temas.py", "5_resumo.py"]

for etapa in ETAPAS:
    print(f"\n{'='*60}\n  {etapa}\n{'='*60}")
    runpy.run_path(str(AQUI / etapa), run_name="__main__")

print("\n✓ Pipeline concluido. Rode o painel com:  streamlit run app.py")
