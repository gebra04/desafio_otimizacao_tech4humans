# Consultas da API: campos utilizados e seleção reduzida

Inventário das 11 chamadas SQL em [api/src/rotas.js](api/src/rotas.js). A execução acontece em [api/src/db.js](api/src/db.js). A rota `/saude` não consulta o banco.

As seleções explícitas descritas abaixo foram aplicadas em api/src/rotas.js. A tabela mantém as consultas originais como referência do antes. O efeito dessa mudança no desempenho ainda não foi medido.

## Consulta original e dados necessários

A coluna “campos necessários” descreve o que precisa voltar para o JavaScript atual. Colunas usadas em `WHERE`, `JOIN`, `GROUP BY` e `ORDER BY` continuam necessárias ao processamento no banco, mesmo quando não precisam aparecer no `SELECT`. Os parâmetros estão na ordem de `$1`, `$2` e `$3`.

| Uso na API | Parâmetros | Consulta original | Campos necessários no retorno | Avaliação |
|---|---|---|---|---|
| Clientes por e-mail | email.trim() | <code>SELECT * FROM clientes WHERE lower(email) = lower($1) ORDER BY id</code> | `id`, `nome`, `email`, `cidade`, `criado_em` | Todos os campos atuais de clientes são usados por formatarCliente(). |
| Cliente por ID | ID do cliente | <code>SELECT * FROM clientes WHERE id = $1</code> | `id`, `nome`, `email`, `cidade`, `criado_em` | Todos os campos atuais de clientes são usados por formatarCliente(). |
| Pedidos do cliente: verificar existência | ID do cliente | <code>SELECT * FROM clientes WHERE id = $1</code> | Uma indicação de existência | O código só verifica se há alguma linha. SELECT 1 preserva essa verificação. |
| Pedidos do cliente: buscar pedidos | ID do cliente | <code>SELECT * FROM pedidos WHERE cliente_id = $1 ORDER BY criado_em DESC, id DESC</code> | `id`, `status`, `criado_em` | Remover cliente_id e observacoes da seleção. id também alimenta a busca dos itens. |
| Pedidos do cliente: buscar itens de cada pedido | ID do pedido | <code>SELECT * FROM itens_pedido WHERE pedido_id = $1 ORDER BY id</code> | `produto_id`, `quantidade`, `preco_unitario_centavos` | Remover id e pedido_id da seleção. Manter ORDER BY id para preservar a ordem dos itens. |
| Pedidos do cliente: buscar produto de cada item | ID do produto | <code>SELECT * FROM produtos WHERE id = $1</code> | `nome` | A resposta usa apenas produto.nome; produto_id já vem do item. |
| Pedidos por status: contar | Status | <code>SELECT count(*) AS total FROM pedidos WHERE status = $1</code> | `total` calculado por count(*) | Já retorna apenas o necessário. count(*) conta linhas; não envia todas as colunas. |
| Pedidos por status: buscar página | Status; tamanho da página; deslocamento | <code>SELECT * FROM pedidos WHERE status = $1 ORDER BY criado_em DESC, id DESC LIMIT $2 OFFSET $3</code> | `id`, `cliente_id`, `status`, `criado_em` | Remover observacoes da seleção. |
| Busca de produtos | Termo de busca sem espaços nas pontas | <code>SELECT * FROM produtos WHERE nome ILIKE '%' &#124;&#124; $1 &#124;&#124; '%' ORDER BY nome, id LIMIT 20</code> | `id`, `nome`, `categoria`, `preco_centavos` | Todos os campos atuais de produtos são usados na resposta. |
| Vendas por dia | Data inicial; data final | <code>SELECT p.id AS pedido_id, p.criado_em, p.observacoes, i.quantidade, i.preco_unitario_centavos FROM pedidos p JOIN itens_pedido i ON i.pedido_id = p.id WHERE p.criado_em::date BETWEEN $1 AND $2 AND p.status &lt;&gt; 'cancelado'</code> | `pedido_id`, `criado_em`, `quantidade`, `preco_unitario_centavos` | Remover p.observacoes. Os demais campos alimentam o agrupamento e os cálculos na API. |
| Top produtos | Limite de produtos | <code>SELECT pr.id, pr.nome, pr.categoria, sum(i.quantidade) AS unidades, sum(i.quantidade * i.preco_unitario_centavos) AS receita_centavos FROM itens_pedido i JOIN pedidos p ON p.id = i.pedido_id JOIN produtos pr ON pr.id = i.produto_id WHERE p.status &lt;&gt; 'cancelado' GROUP BY pr.id, pr.nome, pr.categoria ORDER BY receita_centavos DESC, pr.id LIMIT $1</code> | `id`, `nome`, `categoria`, `unidades`, `receita_centavos` | Todos os campos selecionados são usados na resposta. Nenhuma redução de projeção identificada. |

## SQL com seleção explícita

As versões abaixo mantêm filtros, junções, ordenação, paginação, agregações e quantidade de consultas. Onde todos os campos já são usados, explicitar as colunas não reduz a quantidade de dados retornados no esquema atual.

### Clientes por e-mail

```sql
SELECT id, nome, email, cidade, criado_em FROM clientes WHERE lower(email) = lower($1) ORDER BY id;
```

### Cliente por ID

```sql
SELECT id, nome, email, cidade, criado_em FROM clientes WHERE id = $1;
```

### Pedidos do cliente: verificar existência

```sql
SELECT 1 AS existe FROM clientes WHERE id = $1;
```

### Pedidos do cliente: buscar pedidos

```sql
SELECT id, status, criado_em FROM pedidos WHERE cliente_id = $1 ORDER BY criado_em DESC, id DESC;
```

### Pedidos do cliente: buscar itens de cada pedido

```sql
SELECT produto_id, quantidade, preco_unitario_centavos FROM itens_pedido WHERE pedido_id = $1 ORDER BY id;
```

### Pedidos do cliente: buscar produto de cada item

```sql
SELECT nome FROM produtos WHERE id = $1;
```

### Pedidos por status: contar

```sql
SELECT count(*) AS total FROM pedidos WHERE status = $1;
```

### Pedidos por status: buscar página

```sql
SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = $1 ORDER BY criado_em DESC, id DESC LIMIT $2 OFFSET $3;
```

### Busca de produtos

```sql
SELECT id, nome, categoria, preco_centavos FROM produtos WHERE nome ILIKE '%' || $1 || '%' ORDER BY nome, id LIMIT 20;
```

### Vendas por dia

```sql
SELECT p.id AS pedido_id, p.criado_em, i.quantidade, i.preco_unitario_centavos
       FROM pedidos p
       JOIN itens_pedido i ON i.pedido_id = p.id
      WHERE p.criado_em::date BETWEEN $1 AND $2
        AND p.status <> 'cancelado';
```

### Top produtos

```sql
SELECT pr.id, pr.nome, pr.categoria,
            sum(i.quantidade) AS unidades,
            sum(i.quantidade * i.preco_unitario_centavos) AS receita_centavos
       FROM itens_pedido i
       JOIN pedidos p ON p.id = i.pedido_id
       JOIN produtos pr ON pr.id = i.produto_id
      WHERE p.status <> 'cancelado'
      GROUP BY pr.id, pr.nome, pr.categoria
      ORDER BY receita_centavos DESC, pr.id
      LIMIT $1;
```

## Hipótese e verificação do experimento

A hipótese é reduzir o volume transferido e os objetos criados pela API ao deixar de retornar campos sem uso. Isso não garante menos páginas lidas no PostgreSQL nem ganho mensurável de CPU ou latência. A quantidade de consultas dentro dos laços permanece igual.

Os candidatos que realmente removem dados são: verificação de existência do cliente, pedidos do cliente, itens de cada pedido, produto de cada item, página de pedidos por status e vendas por dia. As buscas que devolvem o cadastro completo do cliente ou do produto já usam todas as colunas atuais. Top produtos e a contagem por status também já selecionam apenas os resultados necessários.

Para medir, seguir o AGENTS.md: registrar a mudança em commit, aplicar a API, comparar o contrato e executar pelo menos três medições com os mesmos parâmetros da linha de base. O contexto deve registrar zero arquivos alterados sem commit. Os números devem vir dos arquivos gerados em resultados/, sem edição manual.
