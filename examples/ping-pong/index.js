'use strict';

const {
    getDefaultProvider,
    Contract,
    constants: { AddressZero },
    utils: { defaultAbiCoder },
} = require('ethers');
const {
    utils: { deployContract },
} = require('@axelar-network/axelar-local-dev');

const { sleep } = require('../../utils');
const PingSender = require('../../artifacts/examples/ping-pong/PingSender.sol/PingSender.json');
const PingReceiver = require('../../artifacts/examples/ping-pong/PingReceiver.sol/PingReceiver.json');

async function deploy(chain, wallet) {
    console.log(`Deploying PingSender for ${chain.name}.`);
    const sender = await deployContract(wallet, PingSender, [chain.gateway, chain.gasReceiver, chain.name]);
    chain.pingSender = sender.address;
    console.log(`Deployed PingSender for ${chain.name} at ${chain.pingSender}.`);

    console.log(`Deploying PingReceiver for ${chain.name}.`);
    const receiver = await deployContract(wallet, PingReceiver, [chain.gateway]);
    chain.pingReceiver = receiver.address;
    console.log(`Deployed PingReceiver for ${chain.name} at ${chain.pingReceiver}.`);
}

async function test(chains, wallet, options) {
    const args = options.args || [];
    const getGasPrice = options.getGasPrice;

    for (const chain of chains) {
        const provider = getDefaultProvider(chain.rpc);
        chain.wallet = wallet.connect(provider);
        chain.pingSender = new Contract(chain.pingSender, PingSender.abi, chain.wallet);
        chain.pingReceiver = new Contract(chain.pingReceiver, PingReceiver.abi, chain.wallet);
    }

    const source = chains.find((chain) => chain.name === (args[0] || 'Avalanche'));
    const destination = chains.find((chain) => chain.name === (args[1] || 'Fantom'));
    const payload = defaultAbiCoder.encode(['string'], ['PING']);

    const nonceSource = BigInt(await source.pingSender.nonce());
    const nonceDestination = BigInt(await destination.pingReceiver.nonce());

    async function logValue() {
        console.log(`valueSent at ${source.name} is "${await source.pingSender.getValueSent()}"`);
        console.log(`valueReceived at ${source.name} is "${await source.pingSender.getValueReceived()}"`);

        console.log(`valueSent at ${destination.name} is "${await destination.pingReceiver.getValueSent()}"`);
        console.log(`valueReceived at ${destination.name} is "${await destination.pingReceiver.getValueReceived()}"`);
    }

    // Set the gasLimit to 3e5 (a safe overestimate) and get the gas price.
    const gasLimitRemote = 3e5;
    const gasLimitSource = 3e5;
    const gasPriceRemote = await getGasPrice(source, destination, AddressZero);
    const gasPriceSource = await getGasPrice(source, source, AddressZero);
    const gasAmountRemote = BigInt(Math.floor(gasLimitRemote * gasPriceRemote));
    const gasAmountSource = BigInt(Math.floor(gasLimitSource * gasPriceSource));

    const tx = await (
        await source.pingSender.ping(destination.name, destination.pingReceiver.address, payload, gasAmountRemote, {
            value: gasAmountRemote + gasAmountSource,
        })
    ).wait();

    console.log(`--- user -> ${source.name} ---`);
    while ((await source.pingSender.getValueSent()) !== 'PING' || BigInt(await source.pingSender.nonce()) !== nonceSource + 1n) {
        await sleep(2000);
    }
    await logValue();

    console.log(`--- ${source.name} -> ${destination.name} ---`);
    while (
        (await destination.pingReceiver.getValueReceived()) !== 'PING' ||
        BigInt(await destination.pingReceiver.nonce()) !== nonceDestination + 1n
    ) {
        await sleep(2000);
    }
    await logValue();

    console.log(`--- ${destination.name} -> ${source.name} ---`);
    while ((await source.pingSender.getValueReceived()) !== 'PONG') {
        await sleep(2000);
    }
    await logValue();
}

module.exports = {
    deploy,
    test,
};
