const test = require('node:test');
const assert = require('node:assert/strict');
const { EventEmitter } = require('node:events');
const { waitForDrainOrClose } = require('../../android/app/src/main/assets/nodejs-project/stream_backpressure');

test('resolves when downstream drains', async () => {
  const response = new EventEmitter();
  const pending = waitForDrainOrClose(response);
  response.emit('drain');
  assert.equal(await pending, true);
  assert.equal(response.listenerCount('close'), 0);
  assert.equal(response.listenerCount('error'), 0);
});

test('stops waiting when downstream closes', async () => {
  const response = new EventEmitter();
  const pending = waitForDrainOrClose(response);
  response.emit('close');
  assert.equal(await pending, false);
  assert.equal(response.listenerCount('drain'), 0);
  assert.equal(response.listenerCount('error'), 0);
});

test('stops waiting when downstream errors', async () => {
  const response = new EventEmitter();
  const pending = waitForDrainOrClose(response);
  response.emit('error', new Error('socket reset'));
  assert.equal(await pending, false);
  assert.equal(response.listenerCount('drain'), 0);
  assert.equal(response.listenerCount('close'), 0);
});

test('does not wait when downstream is already destroyed', async () => {
  const response = new EventEmitter();
  response.destroyed = true;
  assert.equal(await waitForDrainOrClose(response), false);
  assert.equal(response.listenerCount('drain'), 0);
  assert.equal(response.listenerCount('close'), 0);
  assert.equal(response.listenerCount('error'), 0);
});
