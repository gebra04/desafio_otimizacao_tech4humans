EXPLAIN (ANALYZE, BUFFERS)
SELECT pr.id, pr.nome, pr.categoria, vendas.unidades, vendas.receita_centavos
       FROM (
         SELECT i.produto_id,
                sum(i.quantidade) AS unidades,
                sum(i.quantidade * i.preco_unitario_centavos) AS receita_centavos
           FROM itens_pedido i
           JOIN pedidos p ON p.id = i.pedido_id
          WHERE p.status <> 'cancelado'
          GROUP BY i.produto_id
       ) vendas
       JOIN produtos pr ON pr.id = vendas.produto_id
      ORDER BY vendas.receita_centavos DESC, pr.id
      LIMIT 10;
