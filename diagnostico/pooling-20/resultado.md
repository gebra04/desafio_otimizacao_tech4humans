# Experimento: pool de 20 conexões

## Por que testar

O limite anterior de dez conexões foi uma escolha inicial para limitar a concorrência no banco, não um tamanho validado como ótimo. Com vinte usuários virtuais, consultas podem aguardar uma conexão no pool. Este experimento altera apenas max de 10 para 20 no código da API. Idle timeout, consultas, visão materializada e limites de recursos permanecem iguais. O README acompanha o limite atual.

## Validação e condições

O teste [validar-pool.js](validar-pool.js) confere reutilização de conexão, recuperação após erro SQL e atendimento concorrente acima do limite configurado. A saída está em [validacao.txt](validacao.txt).

O contrato foi mantido nos 42 casos antes da carga e após cada medição. As três medições registram o commit 725e511 e zero arquivos alterados sem commit. Parâmetros iguais: VUS=20, DURACAO=60s, AQUECIMENTO=15s e SEMENTE=42. Os serviços foram reiniciados para aplicar a API; os dados não foram recriados.

## Comparação

Cada célula é o valor central de três resultados gerados pelo medir.sh. As linhas de latência por rota representam medianas das medianas; recursos são medianas das médias por execução. A coluna sem pool mantém a visão materializada ativa. O comparador direto é o pool de dez conexões.

| Métrica | Sem pool | Pool 10 | Pool 20 |
|---|---:|---:|---:|
| Requisições/s gerais | 1.70 | 2.10 | 2.05 |
| Mediana geral (ms) | 2454.5 | 2742.8 | 2140.3 |
| p95 geral (ms) | 35647.9 | 35226.5 | 30577.7 |
| Erros gerais (%) | 0.00 | 0.00 | 0.00 |
| Cliente por ID: mediana (ms) | 399.4 | 1098.3 | 96.9 |
| Cliente por e-mail: mediana (ms) | 2549.6 | 2801.4 | 2251.5 |
| Pedidos do cliente: mediana (ms) | 31614.8 | 28302.1 | 25300.6 |
| Pedidos por status: mediana (ms) | 17605.4 | 9753.2 | 17896.0 |
| Busca de produtos: mediana (ms) | 1300.5 | 1602.9 | 819.0 |
| Vendas por dia: mediana (ms) | 20136.8 | 6898.6 | 18245.2 |
| Top produtos: mediana (ms) | 300.2 | 1305.5 | 106.1 |
| CPU média do banco (%) | 98.2 | 98.0 | 98.1 |
| Memória média do banco (MiB) | 208.9 | 192.4 | 216.8 |
| CPU média da API (%) | 6.9 | 6.0 | 5.7 |
| Memória média da API (MiB) | 26.5 | 26.8 | 26.8 |

Com vinte conexões, cliente por ID e top-produtos melhoraram nas três execuções frente ao pool de dez; mediana e p95 gerais também foram menores. Pedidos por status e vendas por dia ficaram mais lentos na mediana, e a vazão central foi ligeiramente menor. A diferença de vazão não prova uma vantagem estável entre os limites: a variabilidade e o número de execuções limitam essa conclusão.

Os resultados são compatíveis com menos espera no pool e maior concorrência entre consultas no banco, mas não foi medido separadamente o tempo de espera por conexão. Há apenas uma chamada de top-produtos por execução.

A CPU do banco continua próxima do limite; a memória observada foi maior com vinte conexões. Os limites de recursos não aumentaram, mas permitir mais conexões simultâneas tem custo potencial de memória. Cache, reinício dos serviços e ordem de execução também podem influenciar o consumo. Este teste não comprova redução global de custo nem que vinte seja o melhor tamanho para qualquer carga.

O limite de vinte foi mantido como solicitado. Para a carga medida, ele favoreceu a latência geral e das rotas rápidas, com piora em algumas consultas pesadas.

## Medições

### Sem pool

- [20261105-171636-03-top-produtos-resumo](../../resultados/20261105-171636-03-top-produtos-resumo/)
- [20261105-171836-03-top-produtos-resumo](../../resultados/20261105-171836-03-top-produtos-resumo/)
- [20261105-172034-03-top-produtos-resumo](../../resultados/20261105-172034-03-top-produtos-resumo/)
### Pool 10

- [20261105-173007-04-pooling](../../resultados/20261105-173007-04-pooling/)
- [20261105-173202-04-pooling](../../resultados/20261105-173202-04-pooling/)
- [20261105-173357-04-pooling](../../resultados/20261105-173357-04-pooling/)
### Pool 20

- [20261105-174341-05-pooling-20](../../resultados/20261105-174341-05-pooling-20/)
- [20261105-174532-05-pooling-20](../../resultados/20261105-174532-05-pooling-20/)
- [20261105-174725-05-pooling-20](../../resultados/20261105-174725-05-pooling-20/)

## Referência da linha de base original

A linha de base anterior a todas as otimizações teve mediana de 1.48 req/s e p95 geral de 46470.1 ms, nos testes [08:43:20](../../resultados/20261105-084320-00-linha-de-base/), [08:47:47](../../resultados/20261105-084747-00-linha-de-base/) e [08:49:45](../../resultados/20261105-084945-00-linha-de-base/). Essa comparação acumula várias mudanças e seus contextos registram arquivo pendente; não isola o efeito do pool de vinte.
