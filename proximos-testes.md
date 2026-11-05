## Teste concluído: totais vendidos por produto

Foi criada a visão materializada `vendas_por_produto`, consultada pela rota top-produtos. O contrato foi mantido e foram feitas três medições com os mesmos parâmetros anteriores, em uma cópia de trabalho limpa. Código, validações e resultados foram registrados em commits separados do rascunho experimentos.md.

O resumo é criado junto com o banco. Como a API possui apenas leitura, não há atualização automática; alterações externas em pedidos ou itens exigem `REFRESH MATERIALIZED VIEW vendas_por_produto`. A equivalência dos totais após alterações e refresh foi testada com rollback.

Comparação completa, custos e pastas: [resultado.md](diagnostico/top-produtos-resumo/resultado.md).

## Pendências

- Se houver escritas: definir atualização transacional por triggers ou política de refresh e testar consistência e custo de escrita.
- Para a carga atual: investigar índices e consultas repetidas da rota pedidos-do-cliente, que continua lenta. Ainda não implementado nem medido.


## Teste concluído: pooling

Antes das demais pendências, foi implementado um único pg.Pool com até dez conexões e realizadas três medições, com contrato mantido. A vazão aumentou, mas houve regressão de latência em algumas rotas. Comparação, validação e limitações em [resultado.md](diagnostico/pooling/resultado.md). O ajuste de outros tamanhos de pool permanece como experimento futuro.


## Teste concluído: pool de 20 conexões

O limite de vinte foi comparado ao de dez em três medições com os mesmos parâmetros e contrato mantido. O limite atual é vinte: melhorou a latência geral e das rotas rápidas nas medições, com piora em algumas consultas pesadas e sem ganho de vazão sobre dez. Comparação completa em [resultado.md](diagnostico/pooling-20/resultado.md).
