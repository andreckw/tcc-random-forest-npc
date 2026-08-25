# Random Forest para NPCs na Godot

Projeto de TCC que compara uma árvore de decisão escrita em C# com cinco perfis de
Random Forest para selecionar as ações de NPCs em um simulador 2D na Godot.

## O que está implementado

- coleta do dataset na Godot em CSV e JSON;
- contrato único de 12 atributos e 5 ações entre C# e Python;
- geração alternativa de 5.000 amostras sintéticas (mínimo aceito: 100; para o
  experimento do TCC recomenda-se pelo menos 2.000);
- cinco Random Forests identificadas como **Nicolas, Andre, Renan, Luiz e Victor**;
- validação cruzada estratificada, teste final compartilhado e métricas por classe;
- exportação separada em Joblib, ONNX e JSON compatível com a Godot;
- `NpcRandomForest` para executar qualquer um dos cinco modelos no jogo;
- verificação automática de paridade entre scikit-learn, ONNX e runtime JSON.

A metodologia, os hiperparâmetros e as decisões de projeto estão em
[docs/RANDOM_FOREST.md](docs/RANDOM_FOREST.md). Os números do experimento
reproduzível estão em [docs/RESULTADOS.md](docs/RESULTADOS.md).

## Execução rápida

Requisitos: Python 3.11 ou mais recente, Godot 4.7 .NET e .NET 8 SDK.

```powershell
cd training
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
python train_random_forest.py
python -m unittest -v test_train_random_forest.py
```

O comando treina os cinco perfis com a mesma base e grava:

- resultados comparativos em `training/artifacts/RESULTADOS.md`;
- métricas em `training/artifacts/comparison.json` e `comparison.csv`;
- modelos separados em `training/artifacts/models/<Nome>/`;
- modelos consumidos pela Godot em `npc-godot/Models/<Nome>.json`.

Para usar o dataset real coletado na Godot:

```powershell
python training/train_random_forest.py --dataset "C:\caminho\dataset.csv"
```

## Uso na Godot

1. Copie a pasta `npc-godot` para `res://addons/npc-godot` no projeto Godot.
2. Ative o plugin em **Project > Project Settings > Plugins**.
3. Use `NpcRandomForest` no NPC (a cena de protótipo já referencia essa classe).
4. Escolha `Nicolas`, `Andre`, `Renan`, `Luiz` ou `Victor` em `modelProfile` no
   Inspector. O padrão atual é Victor, vencedor do experimento documentado. O
   campo `customModelPath` permite apontar para outro JSON.

O perfil vencedor da última execução fica registrado em
`npc-godot/Models/selected_profile.txt`. A árvore de decisão original foi mantida
como baseline e como geradora da regra sintética.

## Estrutura principal

```text
npc-godot/
  AlgorithmsNpc/DecisionTreeNpc/     baseline e coleta das decisões
  AlgorithmsNpc/RandomForestNpc/     inferência das cinco florestas
  Models/                            modelos JSON gerados
training/
  train_random_forest.py             treino, comparação e exportação
  test_train_random_forest.py        testes automatizados
docs/
  RANDOM_FOREST.md                   documentação técnica e experimental
```

## Prototipação

O protótipo usa Godot 4.7 .NET. Além do classificador, ainda fazem parte do escopo
do simulador as animações, os estados, o spawn de NPCs, a câmera, a inspeção do
estado atual e a construção do mundo 2D.
