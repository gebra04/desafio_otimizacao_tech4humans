-- Resumo para a API de leitura. Atualizar após alterações nos pedidos ou itens:
-- REFRESH MATERIALIZED VIEW vendas_por_produto;
CREATE MATERIALIZED VIEW vendas_por_produto AS
SELECT i.produto_id,
       sum(i.quantidade) AS unidades,
       sum(i.quantidade * i.preco_unitario_centavos) AS receita_centavos
  FROM itens_pedido i
  JOIN pedidos p ON p.id = i.pedido_id
 WHERE p.status <> 'cancelado'
 GROUP BY i.produto_id;

CREATE UNIQUE INDEX vendas_por_produto_produto_idx
    ON vendas_por_produto (produto_id);

CREATE INDEX vendas_por_produto_ranking_idx
    ON vendas_por_produto (receita_centavos DESC, produto_id);

ANALYZE vendas_por_produto;
