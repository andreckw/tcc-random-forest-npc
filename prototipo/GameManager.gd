extends Node

var dinheiro: int = 0

var eficiencia: int = 1
var fortuna: int = 1


func adicionar_dinheiro(valor: int):
	dinheiro += valor
	print("Dinheiro:", dinheiro)


func atualizar_eficiencia(novo_valor: int):
	if novo_valor > eficiencia:
		eficiencia = novo_valor
		print("Eficiência atualizada para:", eficiencia)


func atualizar_fortuna(novo_valor: int):
	if novo_valor > fortuna:
		fortuna = novo_valor
		print("Fortuna atualizada para:", fortuna)
