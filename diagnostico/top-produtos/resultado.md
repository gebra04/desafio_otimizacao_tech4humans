# Experimento: agregar vendas antes de juntar produtos

Alteração de código: commit `736f880`, somente na consulta de `/relatorios/top-produtos`. A subconsulta soma unidades e receita por produto após excluir pedidos cancelados; a junção com produtos acontece depois da agregação. A ordenação continua por receita decrescente e ID crescente. Nenhum campo, índice, trigger, serviço ou limite de recursos foi adicionado.

## Execuções comparadas

Comparação imediata com os testes do commit `299afbd`, que já selecionava apenas os campos necessários. Parâmetros iguais: VUS=20, DURACAO=60s, AQUECIMENTO=15s, SEMENTE=42.

Antes:

- [20261105-163835-00-linha-de-base](../../resultados/20261105-163835-00-linha-de-base/resumo.txt)
- [20261105-164048-00-linha-de-base](../../resultados/20261105-164048-00-linha-de-base/resumo.txt)
- [20261105-164252-00-linha-de-base](../../resultados/20261105-164252-00-linha-de-base/resumo.txt)

Depois (contexto sem alterações pendentes):

- [20261105-165435-02-top-produtos-agregacao](../../resultados/20261105-165435-02-top-produtos-agregacao/resumo.txt)
- [20261105-165635-02-top-produtos-agregacao](../../resultados/20261105-165635-02-top-produtos-agregacao/resumo.txt)
- [20261105-170029-02-top-produtos-agregacao](../../resultados/20261105-170029-02-top-produtos-agregacao/resumo.txt)

A execução `20261105-165832-02-top-produtos-agregacao` também foi preservada, mas ficou fora desta comparação porque seu contexto registrou alteração pendente em experimentos.md. A repetição usa o commit `b9984d2`, que acrescenta apenas anotações; o código da API é o mesmo do commit `736f880`.

Os testes anteriores registram um arquivo sem commit. Portanto, esta comparação é indicativa e tem essa limitação de rastreabilidade. As medições seguintes devem continuar com contexto limpo.

## Mediana das três execuções

Cada célula abaixo é o valor central entre os três valores já gerados pelo medir.sh. Para CPU e memória, trata-se da mediana das médias por execução, não da média de todas as amostras combinadas.

| Métrica | Antes | Depois |
|---|---:|---:|
| Requisições/s gerais | 1.60 | 1.65 |
| p95 geral (ms) | 42920.7 | 41479.9 |
| Erros gerais (%) | 0.82 | 0.00 |
| Tempo de top-produtos (ms; antes limitado pelo timeout) | 60000.9 | 50005.3 |
| Erros de top-produtos (%) | 100.0 | 0.0 |
| CPU média do banco (%) | 98.1 | 98.4 |
| Memória média do banco (MiB) | 233.9 | 362.9 |
| CPU média da API (%) | 6.2 | 6.9 |
| Memória média da API (MiB) | 60.9 | 26.8 |

## Interpretação

Top produtos respondeu sem falha nas três execuções selecionadas, enquanto atingia o timeout nas três anteriores. Há apenas uma chamada dessa rota por execução; sua latência ainda varia bastante. O tempo anterior representa o limite de espera do cliente, não o tempo real de conclusão da consulta.

O resultado geral não mostra uma transformação ampla da aplicação: a CPU do banco continua próxima do limite e a memória média observada do banco aumentou. A memória observada da API diminuiu, mas o reinício da API e o estado do cache e do heap são fatores que impedem atribuir essa diferença apenas ao SQL. Não houve aumento dos limites de recursos, mas também não há evidência de redução global de custo.

O contrato foi mantido nos 42 casos antes da carga e após cada uma das quatro execuções. Ver contratos nas respectivas pastas de resultados.

## Diagnóstico e próximo experimento

Os planos estão em [antes-plano.txt](antes-plano.txt) e [depois-plano.txt](depois-plano.txt), com os SQLs usados ao lado. Foram executados isoladamente, em sequência, sem representar o tempo sob concorrência. O plano posterior confirma a agregação por produto antes da junção com o cadastro; ambos ainda percorrem itens e pedidos para calcular os totais.

Se o objetivo for tornar o ranking rápido e previsível, o próximo experimento é persistir os totais por produto em uma visão materializada ou tabela de resumo, medindo também armazenamento e custo de atualização. Essa alternativa ainda não foi implementada nem medida. Em caso de mudanças nos pedidos ou itens, o resumo precisa ser atualizado para manter o contrato.
