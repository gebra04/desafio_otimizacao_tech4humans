const assert = require('node:assert/strict');
const { consultar } = require('/app/src/db');

async function validar() {
  const [primeira] = await consultar('SELECT pg_backend_pid() AS pid');
  const [segunda] = await consultar('SELECT pg_backend_pid() AS pid');
  assert.equal(primeira.pid, segunda.pid);
  console.log('OK: consultas sequenciais reutilizam a conexão');

  await assert.rejects(consultar('SELECT 1 / 0'), { code: '22012' });
  const [aposErro] = await consultar('SELECT 1 AS valor');
  assert.equal(aposErro.valor, 1);
  console.log('OK: conexão devolvida ao pool após erro SQL');

  const respostas = await Promise.all(Array.from({ length: 25 }, () =>
    consultar('SELECT pg_backend_pid() AS pid, pg_sleep(0.05)')));
  const pids = new Set(respostas.map(([linha]) => linha.pid));
  assert.ok(pids.size <= 20);
  assert.equal(respostas.length, 25);
  console.log('OK: consultas concorrentes concluem respeitando o limite de conexões');
}

validar().then(() => process.exit(0)).catch((erro) => {
  console.error(erro);
  process.exit(1);
});
