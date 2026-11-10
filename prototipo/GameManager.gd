extends Node

var dinheiro: int = 0

var qtd_npcs:int = 50
var min_bench:float = 10

func adicionar_dinheiro(valor: int):
	dinheiro += valor
	print("Dinheiro:", dinheiro)
