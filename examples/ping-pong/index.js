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

async function deploy(chain, wallet) {
    console.log(`Deploying PingSender for ${chain.name}.`);
    const contract = await deployContract(wallet, PingSender, [chain.gateway, chain.gasReceiver]);
    chain.pingSender = contract.address;
    console.log(`Deployed PingSender for ${chain.name} at ${chain.pingSender}.`);
}

async function test(chains, wallet, options) {
    const args = options.args || [];
    const getGasPrice = options.getGasPrice;

    for (const chain of chains) {
        const provider = getDefaultProvider(chain.rpc);
        chain.wallet = wallet.connect(provider);
        chain.contract = new Contract(chain.pingSender, PingSender.abi, chain.wallet);
    }

    const source = chains.find((chain) => chain.name === (args[0] || 'Avalanche'));
    const destination = chains.find((chain) => chain.name === (args[1] || 'Fantom'));
    const payload = defaultAbiCoder.encode(['string'], ['PING']);

    async function logValue() {
        console.log(`valueSent at ${source.name} is "${await source.contract.valueSent()}"`);
        console.log(`valueReceived at ${source.name} is "${await source.contract.valueReceived()}"`);

        console.log(`valueSent at ${destination.name} is "${await destination.contract.valueSent()}"`);
        console.log(`valueReceived at ${destination.name} is "${await destination.contract.valueReceived()}"`);
    }

    console.log('--- Initially ---');
    await logValue();

    //Set the gasLimit to 3e5 (a safe overestimate) and get the gas price.
    const gasLimitRemote = 3e5;
    const gasLimitSource = 3e5;
    const gasPriceRemote = await getGasPrice(source, destination, AddressZero);
    const gasPriceSource = await getGasPrice(source, source, AddressZero);
    const gasAmountRemote = BigInt(Math.floor(gasLimitRemote * gasPriceRemote));
    const gasAmountSource = BigInt(Math.floor(gasLimitSource * gasPriceSource));

    const tx = await (
        await source.contract.ping(destination.name, destination.pingSender, payload, gasAmountRemote, {
            value: gasAmountRemote + gasAmountSource,
        })
    ).wait();

    //
    while ((await source.contract.valueSent()) !== 'PING') {
        await sleep(2000);
    }

    console.log('--- user -> source ---')
    await logValue();

    //
    while ((await destination.contract.valueReceived()) !== 'PING') {
        await sleep(2000);
    }

    console.log('--- source -> destination ---')
    await logValue();


    //
    while ((await source.contract.valueReceived()) !== 'PONG') {
        await sleep(2000);
    }

    console.log('--- destination -> source ---')
    await logValue();
}

module.exports = {
    deploy,
    test,
};
