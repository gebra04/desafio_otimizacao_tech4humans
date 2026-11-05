# Experimento: resumo persistido de vendas por produto

## Alteração e consistência

O SQL `banco/03-vendas-por-produto.sql` cria `vendas_por_produto`, uma visão materializada com unidades e receita por produto, excluindo pedidos cancelados. A rota consulta o resumo, junta o cadastro atual e mantém a ordenação por receita decrescente e ID crescente. O SQL preserva a expressão de cálculo de receita e os tipos das somas. Índices atendem ao identificador do produto e à ordenação do ranking.

A API só possui leitura e os dados sintéticos não mudam durante a carga. O resumo é calculado na inicialização. Não foram adicionados triggers: alterações externas em pedidos ou itens exigem `REFRESH MATERIALIZED VIEW vendas_por_produto` antes de novas leituras para manter os resultados atualizados. Essa solução não oferece atualização automática nem consistência imediata após escritas externas.

## Validação

Contrato mantido nos 42 casos antes da carga e após cada uma das três medições. O teste [validar-resumo.sql](validar-resumo.sql) compara todo o resumo à agregação original, simula cancelamento, alteração de quantidade, inserção e exclusão de itens e confere novamente após refresh. A transação é revertida para preservar os dados usados na carga. Saída: [validacao.txt](validacao.txt).

As medições usam VUS=20, DURACAO=60s, AQUECIMENTO=15s e SEMENTE=42, com o commit `062ff99` e zero arquivos alterados sem commit. Não houve aumento nos limites de CPU ou memória, nem serviços adicionais.

## Comparação

Cada célula é a mediana dos três valores produzidos pelo medir.sh. CPU e memória são medianas das médias ou máximos por execução, conforme o nome da linha; não são médias de todas as amostras combinadas. A coluna de agregação por chamada é o comparador imediato. A linha de base original é incluída como referência do início do desafio e registra arquivo pendente nos contextos.

| Métrica | Linha de base original | Agregação por chamada | Resumo persistido |
|---|---:|---:|---:|
| Requisições/s gerais | 1.48 | 1.65 | 1.70 |
| p95 geral (ms) | 46470.1 | 41479.9 | 35647.9 |
| Erros gerais (%) | 0.87 | 0.00 | 0.00 |
| Tempo de top-produtos (ms) | 60000.7 | 50005.3 | 300.2 |
| Erros de top-produtos (%) | 100.0 | 0.0 | 0.0 |
| CPU média do banco (%) | 97.1 | 98.4 | 98.2 |
| Memória média do banco (MiB) | 245.0 | 362.9 | 208.9 |
| Máximo de memória do banco (MiB) | 283.1 | 388.0 | 228.7 |
| CPU média da API (%) | 7.7 | 6.9 | 6.9 |
| Memória média da API (MiB) | 30.8 | 26.8 | 26.5 |
| Máximo de memória da API (MiB) | 37.5 | 30.4 | 30.9 |

O tempo de top-produtos na linha de base original é o limite de espera do cliente; não é o tempo real de conclusão da consulta. Houve apenas uma chamada dessa rota em cada execução. A melhora da rota aparece nas três novas medições, mas a melhora geral é menor: outras rotas continuam caras e a CPU do banco permanece próxima do limite.

A memória observada do banco diminuiu em relação ao experimento anterior, porém houve recriação obrigatória do banco para aplicar o SQL; o estado de cache e a sequência de execuções diferem. Não é possível atribuir toda essa diferença ao resumo nem concluir redução global de custo a partir disso.

## Custo adicional e atualização

O diagnóstico salvo em validacao.txt registrou 2121728 bytes para a visão e seus índices, sendo 1048576 bytes da visão sem os índices. O refresh isolado, após reverter as alterações de teste, registrou 2007.894 ms. Esses valores são diagnósticos, não resultados do teste de carga. O trabalho de agregação foi transferido da requisição para a inicialização e para os refreshes; não foi eliminado. O refresh padrão pode bloquear leituras do resumo durante sua execução. O custo de atualizações frequentes não foi medido sob carga.

O plano salvo no mesmo arquivo confirma a busca do ranking pelo índice e a junção dos produtos retornados. Tempos de EXPLAIN isolado não devem ser confundidos com a latência HTTP sob concorrência.

## Fontes das medições

### Linha de base original

- [20261105-084320-00-linha-de-base](../../resultados/20261105-084320-00-linha-de-base/): resumo, recursos, contexto e contrato.
- [20261105-084747-00-linha-de-base](../../resultados/20261105-084747-00-linha-de-base/): resumo, recursos, contexto e contrato.
- [20261105-084945-00-linha-de-base](../../resultados/20261105-084945-00-linha-de-base/): resumo, recursos, contexto e contrato.
### Agregação por chamada

- [20261105-165435-02-top-produtos-agregacao](../../resultados/20261105-165435-02-top-produtos-agregacao/): resumo, recursos, contexto e contrato.
- [20261105-165635-02-top-produtos-agregacao](../../resultados/20261105-165635-02-top-produtos-agregacao/): resumo, recursos, contexto e contrato.
- [20261105-170029-02-top-produtos-agregacao](../../resultados/20261105-170029-02-top-produtos-agregacao/): resumo, recursos, contexto e contrato.
### Resumo persistido

- [20261105-171636-03-top-produtos-resumo](../../resultados/20261105-171636-03-top-produtos-resumo/): resumo, recursos, contexto e contrato.
- [20261105-171836-03-top-produtos-resumo](../../resultados/20261105-171836-03-top-produtos-resumo/): resumo, recursos, contexto e contrato.
- [20261105-172034-03-top-produtos-resumo](../../resultados/20261105-172034-03-top-produtos-resumo/): resumo, recursos, contexto e contrato.

## Próximo passo

Se o escopo incluir escritas, definir e testar manutenção transacional do resumo ou uma política explícita de atualização. Para melhorar o desempenho geral da API de leitura, investigar planos e índices das buscas de pedidos e reduzir as consultas dentro de laços em pedidos-do-cliente. Essas alterações não fazem parte deste experimento.
