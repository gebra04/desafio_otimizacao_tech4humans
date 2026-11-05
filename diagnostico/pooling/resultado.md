# Experimento: pooling PostgreSQL

## Alteração

O módulo db.js passa a manter um único pg.Pool por processo, com max=10 e idleTimeoutMillis=30000. Cada consulta usa pool.query(), que obtém e devolve a conexão automaticamente. Erros de conexões ociosas são registrados pelo listener do pool. As consultas SQL e as respostas HTTP não foram alteradas. Não houve aumento de CPU ou memória configurados, serviços adicionais nem alteração de max_connections no PostgreSQL.

A mudança reúne reutilização de conexões e limite de concorrência: ao ocupar as dez conexões, consultas adicionais aguardam no pool. Estes testes não isolam a contribuição de cada mecanismo. O limite de dez é um primeiro experimento, não o dimensionamento comprovadamente ótimo.

## Validação

[validar-pool.js](validar-pool.js) executado na imagem da API verificou reutilização sequencial da conexão, continuidade após erro SQL e conclusão de consultas concorrentes acima do limite do pool. Saída em [validacao.txt](validacao.txt).

Contrato mantido nos 42 casos antes da carga e após cada medição. As três execuções registraram o commit 2569594 e zero arquivos alterados sem commit, com VUS=20, DURACAO=60s, AQUECIMENTO=15s e SEMENTE=42. A visão materializada do experimento anterior permanece ativa; não houve recriação dos dados nesta etapa, mas os serviços foram reiniciados para aplicar a API.

## Comparação com a versão imediatamente anterior

Valores centrais dos três resultados produzidos pelo medir.sh. Para as rotas, são medianas das medianas por execução; para recursos, medianas das médias. Não são médias de todas as amostras reunidas.

| Métrica | Sem pooling | Pool de 10 conexões |
|---|---:|---:|
| Requisições/s gerais | 1.70 | 2.10 |
| Mediana geral (ms) | 2454.5 | 2742.8 |
| p95 geral (ms) | 35647.9 | 35226.5 |
| Erros gerais (%) | 0.00 | 0.00 |
| Cliente por ID: mediana (ms) | 399.4 | 1098.3 |
| Cliente por e-mail: mediana (ms) | 2549.6 | 2801.4 |
| Pedidos do cliente: mediana (ms) | 31614.8 | 28302.1 |
| Pedidos por status: mediana (ms) | 17605.4 | 9753.2 |
| Busca de produtos: mediana (ms) | 1300.5 | 1602.9 |
| Vendas por dia: mediana (ms) | 20136.8 | 6898.6 |
| Top produtos: mediana (ms) | 300.2 | 1305.5 |
| CPU média do banco (%) | 98.2 | 98.0 |
| Memória média do banco (MiB) | 208.9 | 192.4 |
| CPU média da API (%) | 6.9 | 6.0 |
| Memória média da API (MiB) | 26.5 | 26.8 |

A vazão geral aumentou nas medições, enquanto o p95 geral variou pouco e a mediana geral piorou. Pedidos por status e vendas por dia responderam mais rápido; cliente por ID, busca de produtos e top produtos ficaram mais lentos. A fila do pool é uma explicação compatível com esse comportamento, mas seu tempo de espera não foi instrumentado neste experimento. Top produtos teve apenas uma chamada por execução.

O banco continua próximo do limite de CPU. A memória observada foi menor, mas reinício dos serviços, cache e sequência de execuções impedem atribuir a diferença exclusivamente ao pooling. Conexões mantidas abertas entre consultas também têm custo de memória. Não é possível concluir redução global de custo ou melhora uniforme de todas as rotas.

## Pastas comparadas

Antes:

- [20261105-171636-03-top-produtos-resumo](../../resultados/20261105-171636-03-top-produtos-resumo/)
- [20261105-171836-03-top-produtos-resumo](../../resultados/20261105-171836-03-top-produtos-resumo/)
- [20261105-172034-03-top-produtos-resumo](../../resultados/20261105-172034-03-top-produtos-resumo/)

Depois:

- [20261105-173007-04-pooling](../../resultados/20261105-173007-04-pooling/)
- [20261105-173202-04-pooling](../../resultados/20261105-173202-04-pooling/)
- [20261105-173357-04-pooling](../../resultados/20261105-173357-04-pooling/)

## Limitações e próximos experimentos

Comparar outros tamanhos de pool em experimentos separados se a prioridade for latência das rotas rápidas. Para reduzir o trabalho do banco, investigar índices e consultas repetidas de pedidos-do-cliente. Essas mudanças ainda não foram implementadas nem medidas nesta etapa.
