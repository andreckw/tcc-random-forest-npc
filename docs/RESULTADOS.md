# Resultados do experimento

## Configuração

Resultados obtidos com o comando:

```powershell
python training/train_random_forest.py --samples 5000 --noise 0.15 --seed 42
```

- data da execução: 12 de agosto de 2026;
- 5.000 amostras sintéticas geradas pela política da árvore de decisão;
- exploração configurada em 15%: 753 eventos aleatórios e 607 rótulos
  efetivamente diferentes da decisão original;
- divisão estratificada: 4.000 registros de treino e 1.000 de teste;
- validação cruzada estratificada de 5 folds somente no treino;
- distribuição: Idle 1.965, PatrolWalk 772, Interact 1.557,
  Investigation 505 e Aggressive 201.

## Comparação

| Perfil | Acurácia CV | Acurácia teste | Acurácia balanceada | F1 macro |
|---|---:|---:|---:|---:|
| Nicolas (baseline original) | 0,8230 ± 0,0104 | 0,8380 | 0,6944 | 0,7054 |
| Andre | 0,8408 ± 0,0087 | 0,8570 | 0,6932 | 0,7073 |
| Renan | 0,8298 ± 0,0075 | 0,8480 | 0,6970 | 0,7077 |
| Luiz | 0,8377 ± 0,0085 | 0,8580 | 0,6935 | 0,7088 |
| **Victor** | **0,8520 ± 0,0088** | **0,8680** | **0,6996** | **0,7099** |

Victor foi selecionado pela maior acurácia média da validação, antes de observar o
teste como critério de escolha. Em relação à configuração original Nicolas, o
ganho absoluto foi de **2,9 pontos percentuais na validação cruzada** e **3,0
pontos percentuais no teste final**. Todos os ONNX e JSONs dos cinco perfis
obtiveram 100% de concordância de previsão com o scikit-learn.

Os três atributos mais importantes para Victor foram `hunger` (0,2800), `hour`
(0,1453) e `stamina` (0,1229), resultado coerente com a ordem de regras da árvore
de decisão que originou a base.

## Leitura crítica

A classe Aggressive representa somente 4,02% da base e inclui muitos rótulos
produzidos pela exploração aleatória. Victor acertou a maior proporção global,
mas o recall de Aggressive foi apenas 0,05 (2 de 40 registros no teste). Nicolas,
que usa balanceamento de classes, obteve recall 0,125 nessa classe, com menor
acurácia geral. Portanto, Victor é a escolha quando o objetivo declarado é
acurácia; se detectar ações raras tiver maior custo, deve-se coletar mais casos
Aggressive reais e otimizar uma métrica macro ou recall por classe.

Esses resultados descrevem a recuperação de uma política sintética sob ruído, não
provam qualidade comportamental percebida no jogo. O relatório definitivo do TCC
deve repetir o comando com `--dataset` apontando para o CSV coletado no protótipo.
Quando `npcId` está presente, o pipeline separa NPCs por grupo para impedir
vazamento do mesmo indivíduo entre treino e teste.
