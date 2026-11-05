# Registro de experimentos

## Preparação do ambiente

No Fedora 43, eu já tinha o Docker, mas faltava o plugin Compose. A instalação apresentou conflitos com os pacotes abaixo. Removi esses pacotes e repeti a instalação; depois disso, funcionou.

```bash
containerd-2.2.8-1.fc43.x86_64
docker-buildx-0.37.1-1.fc43.x86_64
moby-filesystem-29.8.2-2.fc43.noarch
docker-cli-29.8.2-2.fc43.x86_64
moby-engine-29.8.2-2.fc43.x86_64
moby-engine-rootless-extras-29.8.2-2.fc43.noarch
moby-engine-nano-29.8.2-2.fc43.noarch
```

## Contrato e linha de base

Gravei o contrato da aplicação original e executei três medições:

```bash
    scripts/verificar-contrato.sh gravar
```

```bash
    scripts/medir.sh 00-linha-de-base
    scripts/medir.sh 00-linha-de-base
    scripts/medir.sh 00-linha-de-base
```

O banco ficou próximo do limite de CPU. Na medição das 08:49, o resumo mostrou média de `99.7%` e máximo de `99.6%`, uma inconsistência ainda sem causa confirmada. Fonte: [recursos.txt](resultados/20261105-084945-00-linha-de-base/recursos.txt).

A rota top-produtos atingiu o timeout do teste:

```bash
WARN[0069] Request Failed error="Get \"http://api:3000/relatorios/top-produtos?limite=10\": request timeout"
```

O banco saturado pode contribuir para a demora, mas as medições não isolam a causa nem o consumo de cada consulta.

## Seleção dos campos necessários

As consultas foram revisadas para retornar apenas os campos usados pela API, conforme [consultas-campos.md](consultas-campos.md), no commit `299afbd`. A hipótese era reduzir a transferência de dados e o uso de memória. As medições não permitiram confirmar uma redução de memória atribuível à alteração.

## Agregação em top-produtos

No commit `736f880`, a consulta passou a somar quantidade e receita por produto antes de juntar nome e categoria. Foram mantidos o filtro de pedidos não cancelados e a ordenação por receita, com desempate pelo ID. Nenhum campo ou trigger foi adicionado.

A comparação abaixo usa três execuções antes e três depois, com `VUS=20`, `DURACAO=60s`, `AQUECIMENTO=15s` e `SEMENTE=42`. O antes já inclui a seleção reduzida de campos. O contrato foi mantido nos 42 casos antes da carga e após cada execução.

| Métrica                      |            Antes |               Depois |
| ---------------------------- | ---------------: | -------------------: |
| Requisições/s gerais         |             1.60 |                 1.65 |
| p95 geral (ms)               |          42920.7 |              41479.9 |
| Erros gerais (%)             |             0.82 |                 0.00 |
| Tempo de top-produtos (ms)   | 60000.9, timeout | 50005.3, sem timeout |
| Erros de top-produtos (%)    |            100.0 |                  0.0 |
| CPU média do banco (%)       |             98.1 |                 98.4 |
| Memória média do banco (MiB) |            233.9 |                362.9 |
| CPU média da API (%)         |              6.2 |                  6.9 |
| Memória média da API (MiB)   |             60.9 |                 26.8 |

Valores: medianas de três execuções; para CPU e memória, medianas das médias. O tempo anterior de top-produtos é o limite de espera do cliente, não o tempo real de conclusão.

A rota respondeu sem falha, mas ainda variou entre 20506.9 ms, 50005.3 ms e 51206.7 ms, com apenas uma chamada por execução. O ganho geral foi pequeno e o banco continuou próximo do limite de CPU. Sua memória aumentou; a da API diminuiu, mas reinício, cache e estado do heap podem influenciar os valores. Não houve aumento dos limites de recursos nem evidência de redução global de custo.

Uma execução com edição pendente neste rascunho foi excluída da comparação e repetida. As três anteriores também registravam um arquivo sem commit, o que limita a rastreabilidade. Pastas das medições, planos de execução e detalhes estão em [resultado.md](diagnostico/top-produtos/resultado.md).


## Resumo persistido de top-produtos

Foi criada a visão materializada `vendas_por_produto` para consultar os totais sem recalcular todas as vendas a cada chamada. Em três medições, a mediana de top-produtos passou de 50005.3 ms para 300.2 ms; a vazão geral passou de 1.65 para 1.70 req/s. O contrato foi mantido nos 42 casos.

A visão exige `REFRESH MATERIALIZED VIEW vendas_por_produto` após alterações externas nos pedidos ou itens. Não há triggers nem atualização automática. O banco foi recriado para aplicar o novo SQL, o que limita a comparação de memória. Validações, armazenamento e custo de refresh estão em [resultado.md](diagnostico/top-produtos-resumo/resultado.md).

## Pool de conexões

O `Client` criado a cada consulta foi substituído por um único `pg.Pool`, com até dez conexões reutilizáveis. Consultas aguardam quando todas estão ocupadas, e conexões ociosas são fechadas após 30000 ms. Foram verificadas a reutilização, a recuperação após erro SQL e a concorrência acima do limite.

Comparação com a visão materializada já ativa, usando três execuções com os mesmos parâmetros de carga:

| Métrica | Sem pooling | Com pooling |
|---|---:|---:|
| Requisições/s gerais | 1.70 | 2.10 |
| Mediana geral (ms) | 2454.5 | 2742.8 |
| p95 geral (ms) | 35647.9 | 35226.5 |
| Pedidos por status: mediana (ms) | 17605.4 | 9753.2 |
| Vendas por dia: mediana (ms) | 20136.8 | 6898.6 |
| Cliente por ID: mediana (ms) | 399.4 | 1098.3 |
| Top-produtos: mediana (ms) | 300.2 | 1305.5 |
| CPU média do banco (%) | 98.2 | 98.0 |
| Memória média do banco (MiB) | 208.9 | 192.4 |

Valores: medianas de três execuções; para recursos, medianas das médias. Todas terminaram sem erro e mantiveram os 42 casos do contrato, com contexto limpo. Não houve aumento de recursos nem alteração das consultas.

A vazão aumentou, mas a mediana geral piorou e algumas rotas rápidas ficaram mais lentas. A espera por conexão pode explicar parte dessa troca; não foi medida separadamente. O p95 geral variou pouco, e o banco continua próximo do limite de CPU. A diferença de memória não pode ser atribuída apenas ao pooling. Outros tamanhos de pool ainda precisam ser comparados. Detalhes e pastas: [resultado.md](diagnostico/pooling/resultado.md).
