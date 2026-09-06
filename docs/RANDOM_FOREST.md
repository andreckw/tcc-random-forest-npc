# Metodologia e implementação das Random Forests

## 1. Objetivo

O pipeline aprende a política de decisão dos NPCs e compara cinco configurações de
`RandomForestClassifier`. Todos os modelos recebem exatamente os mesmos dados, a
mesma divisão treino/teste e a mesma seed. Isso permite atribuir as diferenças de
resultado aos hiperparâmetros, e não a amostras mais fáceis ou mais difíceis.

A árvore de decisão original continua sendo o baseline. Quando não é fornecido um
CSV real, suas regras são reproduzidas de forma vetorizada no Python para gerar o
dataset sintético. A taxa de exploração de 15% do `NpcAgent` também é simulada:
nesses eventos uma ação aleatória é gravada, inclusive quando coincide com a ação
original.

## 2. Contrato dos dados

O contrato canônico está em `NpcFeatureContract.cs` e é repetido no artefato
`feature_contract.json`.

| Ordem | Atributo | Tipo/codificação |
|---:|---|---|
| 1 | `stamina` | contínuo, 0 a 1 |
| 2 | `hunger` | contínuo, 0 a 1 |
| 3 | `hour` | hora dividida por 24, 0 a 1 |
| 4 | `socialClass` | HIGH=0, AVERAGE=1, LOW=2 |
| 5 | `socialStatus` | MARRIED=0, SINGLE=1 |
| 6 | `leisure` | contínuo, 0 a 1 |
| 7 | `priority` | SELF=0, FAMILY=1, WORK=2 |
| 8 | `trait_extraversion` | contínuo, 0 a 1 |
| 9 | `trait_agreeableness` | contínuo, 0 a 1 |
| 10 | `trait_conscientiousness` | contínuo, 0 a 1 |
| 11 | `trait_emotional_stability` | contínuo, 0 a 1 |
| 12 | `trait_openness_exp` | contínuo, 0 a 1 |

A variável-alvo é `acao_alvo`: Idle=0, PatrolWalk=1, Interact=2,
Investigation=3 e Aggressive=4. O carregador rejeita colunas ausentes, valores não
numéricos, NaN, infinitos, categorias desconhecidas, faixas inválidas e datasets
sem exemplos das cinco ações.

Não se aplica normalização adicional: árvores comparam limiares e não dependem da
escala euclidiana. A conversão para `float32` é feita para que os limiares usados
pelo scikit-learn, pelo ONNX e pelo C# tenham comportamento compatível.

## 3. Os cinco perfis

Os nomes são identificadores estáveis das configurações. Todos usam bootstrap,
mas exploram compromissos diferentes entre viés, variância, diversidade e custo.

| Perfil | Árvores | Critério | Profundidade | Folha mín. | Atributos por divisão | Peso de classe | Amostra por árvore |
|---|---:|---|---:|---:|---|---|---:|
| Nicolas | 100 | gini | 10 | 1 | raiz quadrada | balanced | 100% |
| Andre | 300 | entropy | 20 | 1 | todos | balanced_subsample | 100% |
| Renan | 300 | log_loss | 16 | 2 | raiz quadrada | balanced | 100% |
| Luiz | 350 | gini | 18 | 1 | 75% | balanced_subsample | 80% |
| Victor | 500 | log_loss | ilimitada | 1 | todos | sem ajuste | 100% |

- **Nicolas** reproduz a configuração original do repositório e serve de baseline.
- **Andre** permite interações profundas e usa entropia.
- **Renan** exige duas amostras por folha para não memorizar tanto o ruído.
- **Luiz** aumenta a diversidade entre árvores por duas subamostragens.
- **Victor** privilegia capacidade e acurácia bruta; o custo de inferência é maior.

## 4. Protocolo de avaliação

1. O dataset é validado antes de qualquer treino.
2. São reservados 20% para teste com estratificação por ação.
3. Nos 80% restantes, cada perfil passa por validação cruzada estratificada de
   cinco folds.
4. Calculam-se acurácia, acurácia balanceada e F1 macro em cada fold.
5. O vencedor é o perfil com maior acurácia média de validação; F1 macro é apenas
   o desempate. O teste não participa dessa escolha.
6. Depois da avaliação, cada configuração é retreinada com 100% dos registros e
   exportada para produção. Portanto, as métricas pertencem ao modelo treinado
   sem o holdout; os arquivos de produção aproveitam toda a base disponível.

Se o CSV contém `npcId`, a divisão usa grupos: um mesmo NPC nunca aparece ao mesmo
tempo em treino e teste nem em lados diferentes de um fold. Isso evita que traços
fixos do indivíduo vazem para a avaliação e inflem artificialmente a acurácia.

Além da acurácia, a F1 macro e a acurácia balanceada são necessárias porque a ação
Aggressive é naturalmente rara na política atual. A matriz de confusão e o
relatório por classe ficam em `metrics.json` de cada perfil.

## 5. Artefatos e integração

Cada diretório `training/artifacts/models/<Nome>/` contém:

- `model.joblib`: modelo Python para análise ou novo treino;
- `model.onnx`: formato interoperável;
- `model.runtime.json`: representação compacta das árvores para o C#;
- `metrics.json`: configuração, folds, teste, matriz de confusão, importância dos
  atributos, tempos e verificações de paridade.

O script copia os cinco JSONs para `npc-godot/Models`. A classe
`NpcRandomForest` monta o vetor na ordem canônica, percorre cada árvore, soma as
probabilidades das folhas e escolhe o índice com maior valor. Assim, o plugin não
precisa carregar Python, scikit-learn ou ONNX Runtime durante o jogo.
As instâncias que escolhem o mesmo perfil compartilham uma floresta em cache, para
que dezenas de NPCs não repitam a leitura e a desserialização do modelo.

As exportações são aceitas somente quando as previsões em uma amostra de
verificação têm 100% de concordância com o scikit-learn. A forma da saída ONNX
também é verificada para garantir cinco probabilidades.

## 6. Comandos

Treino sintético reproduzível:

```powershell
python training/train_random_forest.py --samples 5000 --noise 0.15 --seed 42
```

Treino com dados coletados na Godot:

```powershell
python training/train_random_forest.py --dataset "C:\caminho\dataset.csv" --seed 42
```

Experimento maior para o texto final do TCC:

```powershell
python training/train_random_forest.py --samples 20000 --noise 0.15 --seed 42
```

Executar somente alguns perfis durante desenvolvimento:

```powershell
python training/train_random_forest.py --profiles Nicolas Renan
```

Testes automatizados:

```powershell
cd training
python -m unittest -v test_train_random_forest.py
```

## 7. Interpretação e limitações

A acurácia no dataset sintético mede quanto a floresta recupera a política da
árvore de decisão sob exploração aleatória. Ela não demonstra, sozinha, que o NPC
parece mais inteligente para jogadores. A evidência principal do TCC deve usar o
CSV observado no protótipo e, idealmente, combinar as métricas offline com uma
avaliação comportamental.

O ruído limita a acurácia máxima: quando a exploração troca deliberadamente a
ação correta por outra aleatória, não existe informação nos 12 atributos que
permita prever essa escolha. Aumentar árvores não elimina esse limite. Também se
deve relatar a distribuição das classes e evitar concluir que um modelo é melhor
apenas por acertar Idle e Interact, que tendem a ser mais frequentes.
