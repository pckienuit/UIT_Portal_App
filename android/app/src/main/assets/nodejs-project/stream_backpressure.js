function waitForDrainOrClose(response) {
  if (response.destroyed || response.writableEnded) return Promise.resolve(false);
  return new Promise((resolve) => {
    let settled = false;
    const finish = (drained) => {
      if (settled) return;
      settled = true;
      response.removeListener('drain', onDrain);
      response.removeListener('close', onClose);
      response.removeListener('error', onError);
      resolve(drained);
    };
    const onDrain = () => finish(true);
    const onClose = () => finish(false);
    const onError = () => finish(false);
    response.once('drain', onDrain);
    response.once('close', onClose);
    response.once('error', onError);
    if (response.destroyed || response.writableEnded) finish(false);
  });
}

async function writeWithBackpressure(response, value) {
  if (response.destroyed || response.writableEnded) return false;
  return response.write(value) || waitForDrainOrClose(response);
}

module.exports = { waitForDrainOrClose, writeWithBackpressure };
