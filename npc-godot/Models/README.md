# Modelos para execução na Godot

Os arquivos `Nicolas.json`, `Andre.json`, `Renan.json`, `Luiz.json` e
`Victor.json` são gerados por `training/train_random_forest.py`. Cada arquivo
contém todas as árvores do perfil correspondente no formato lido por
`RuntimeRandomForest.cs`.

`selected_profile.txt` registra o vencedor da última comparação. No experimento
reproduzível de 5.000 amostras, o perfil selecionado foi Victor.

Não edite os JSONs manualmente. O treinamento valida o contrato de atributos e
ações e exige paridade total com o modelo do scikit-learn antes de copiá-los para
esta pasta.
