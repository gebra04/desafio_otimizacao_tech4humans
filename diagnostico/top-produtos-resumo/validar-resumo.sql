\set ON_ERROR_STOP on
\timing on
BEGIN;
CREATE FUNCTION pg_temp.conferir_resumo() RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF EXISTS (
    WITH esperado AS (
      SELECT i.produto_id, sum(i.quantidade) AS unidades,
             sum(i.quantidade * i.preco_unitario_centavos) AS receita_centavos
        FROM itens_pedido i JOIN pedidos p ON p.id = i.pedido_id
       WHERE p.status <> 'cancelado'
       GROUP BY i.produto_id
    )
    (SELECT * FROM esperado EXCEPT ALL SELECT * FROM vendas_por_produto)
    UNION ALL
    (SELECT * FROM vendas_por_produto EXCEPT ALL SELECT * FROM esperado)
  ) THEN
    RAISE EXCEPTION 'Resumo diverge da agregação original';
  END IF;
END;
$$;
SELECT pg_temp.conferir_resumo();
-- Simula alterações externas: cancelamento, quantidade, inserção e exclusão.
UPDATE pedidos SET status = 'cancelado'
 WHERE id = (SELECT min(id) FROM pedidos WHERE status <> 'cancelado');
UPDATE itens_pedido SET quantidade = quantidade + 1
 WHERE id = (SELECT max(id) FROM itens_pedido);
INSERT INTO itens_pedido (id, pedido_id, produto_id, quantidade, preco_unitario_centavos)
SELECT (SELECT max(id) + 1 FROM itens_pedido), pedido_id, produto_id, quantidade, preco_unitario_centavos
  FROM itens_pedido ORDER BY id DESC LIMIT 1;
DELETE FROM itens_pedido WHERE id = (SELECT min(id) FROM itens_pedido);
REFRESH MATERIALIZED VIEW vendas_por_produto;
SELECT pg_temp.conferir_resumo();
ROLLBACK;
-- O rollback preserva os dados sintéticos e o resumo originais.
SELECT pg_total_relation_size('vendas_por_produto') AS resumo_com_indices_bytes,
       pg_relation_size('vendas_por_produto') AS resumo_sem_indices_bytes;
REFRESH MATERIALIZED VIEW vendas_por_produto;
EXPLAIN (ANALYZE, BUFFERS)
SELECT pr.id, pr.nome, pr.categoria, vendas.unidades, vendas.receita_centavos
  FROM vendas_por_produto vendas
  JOIN produtos pr ON pr.id = vendas.produto_id
 ORDER BY vendas.receita_centavos DESC, pr.id
 LIMIT 10;
