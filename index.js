const { buildProtectedRedisClient } = require('@a0/redis-client');
const noop = () => {};
const levelLog = (level, msg, tags) => {
  console.log({ date: new Date(), level, msg, ...tags });
};
const timedLog = levelLog.bind(null, 'info');
const agent = {
  logger: {
    error: levelLog.bind(null, 'error'),
    warn: levelLog.bind(null, 'warn'),
    info: levelLog.bind(null, 'info')
  },
  metrics: {
    gauge: noop,
    increment: noop,
    incrementOne: noop
  }
};

const seconds = 1000;

const REDIS_CIRCUIT_BREAKER_MAX_FAILURES = 5000;
const REDIS_CIRCUIT_BREAKER_COOLDOWN = 10 * seconds;
const REDIS_CIRCUIT_BREAKER_MAX_COOLDOWN = 30 * seconds;
const REDIS_MIN_RECONNECT_DELAY_MS = 100 * seconds;
const REDIS_MAX_RECONNECT_DELAY_MS = 500 * seconds;
const REDIS_RECONNECT_DELAY_JITTER = 100;
const REDIS_HOST = '127.1.1.1';
const REDIS_PORT = 6379;
const REDIS_PASSWORD = '';
const REDIS_TLS = false;
const REDIS_CLUSTER_MODE = true;
const OPERATION_RETRIES = 0;
const OPERATION_MAX_TIMEOUT_MS = 500;
const OPERATION_MIN_TIMEOUT_MS = 500;

const entitiesCacheRedis = buildProtectedRedisClient({
  name: 'entities_cache_redis',
  commandTimeoutMs: OPERATION_MIN_TIMEOUT_MS,
  maxConnectionRetriesPerRequest: OPERATION_RETRIES,
  keyPrefix: 'entities_cache:',
  host: REDIS_HOST,
  port: REDIS_PORT,
  tls: REDIS_TLS,
  password: REDIS_PASSWORD,
  clusterMode: REDIS_CLUSTER_MODE,
  minReconnectionDelayMs: REDIS_MIN_RECONNECT_DELAY_MS,
  maxReconnectionDelayMs: REDIS_MAX_RECONNECT_DELAY_MS,
  reconnectionDelayJitterMs: REDIS_RECONNECT_DELAY_JITTER,
  minRetryTimeoutMs: OPERATION_MIN_TIMEOUT_MS,
  maxRetryTimeoutMs: OPERATION_MAX_TIMEOUT_MS,
  retries: OPERATION_RETRIES,
  circuitBreaker: {
    maxFailures: REDIS_CIRCUIT_BREAKER_MAX_FAILURES,
    minCooldownMs: REDIS_CIRCUIT_BREAKER_COOLDOWN,
    maxCooldownMs: REDIS_CIRCUIT_BREAKER_MAX_COOLDOWN
  },
  agent
});

function nextOne() {
  entitiesCacheRedis
    .set(Date.now, 'here', 'EX', 10)
    .then(timedLog)
    .catch(timedLog)
    .finally(() => setTimeout(nextOne, 1000));
}

entitiesCacheRedis.connect().then(() => {
  timedLog('done connection');
  nextOne();
});
