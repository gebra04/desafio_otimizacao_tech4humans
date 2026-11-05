1o problema encontrado: Docker não compatível, utilizo fedora 43 e verifiquei que eu tinha o Docker no meu pc, mas não o plugin compose, tentei seguir a instalação pelo site e ele pede para remover alguns arquivos que podem existir no computador que podem dar conflito, usei o comando e tentei a instalação e ele mostrou conflito da mesma forma. Pesquisei um pouco quais eram os pacotes já baixados no Fedora, encontrei esses na minha máquina e deletei, em seguida utilizei o comandos de instalação e funcionou.

```bash
containerd-2.2.8-1.fc43.x86_64
docker-buildx-0.37.1-1.fc43.x86_64
moby-filesystem-29.8.2-2.fc43.noarch
docker-cli-29.8.2-2.fc43.x86_64
moby-engine-29.8.2-2.fc43.x86_64
moby-engine-rootless-extras-29.8.2-2.fc43.noarch
moby-engine-nano-29.8.2-2.fc43.noarch
```

Gravei o contrato e executei os testes

```bash
    scripts/verificar-contrato.sh gravar
```

```bash
    scripts/medir.sh 00-linha-de-base
    scripts/medir.sh 00-linha-de-base
    scripts/medir.sh 00-linha-de-base
```

Pude observar que o `desafio-performance-banco-1` foi o que mais sobrecarregou a aplicação nos 3 testes. No primeiro teste, percebi que a CPU atingiu um máximo de `99.6%`, mas notei uma inconsistência, já que a média `99.7%` foi maior que o máximo registrado, nos outros relatórios de performance o resultado parece normal (mas também com gargalo). Por enquanto, estou considerando que foi apenas um erro de medição por conta do excesso de uso da CPU.

Durante os testes, também obtive um erro de API, por enquanto suponho que tenha sido também pela sobrecarga da CPU, já que no `resumo.txt` é possivel notar que uma requisição foi feita e ela falhou, com aproximadamente 60s, provavelmente o timeout que obtive.

```bash
WARN[0069] Request Failed error="Get \"http://api:3000/relatorios/top-produtos?limite=10\": request timeout"
```

Vou dar uma olhada nas querys do banco para ver se estão otimizadas e verificar se consigo evitar o timeout. Notei duas coisas que podem melhorar o desempenho, ao selecionar as tuplas, muitas colunas que não são utilizadas são selecionadas, isso pode estar ajudando a sobrecarregar a memória, vou testar essa hipótese removendo os campos dispensáveis na busca. A segunda coisa foi que algumas querys precisam de muitos joins e fazem a busca ficar lenta ou impossível no tempo delimitado, vou criar uma coluna do preço vendido de cada produto, pois evita fazer varios joins em uma consulta simples e relativamente comum.

O gasto de memória com a diminuição das colunas não foi notável
