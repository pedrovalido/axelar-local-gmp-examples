// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import { AxelarExecutable } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/executables/AxelarExecutable.sol';
import { IAxelarGateway } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGateway.sol';

contract PingReceiver is AxelarExecutable {
    string public valueSent = '';
    string public valueReceived = '';
    string public constant PING = 'PING';
    string public constant PONG = 'PONG';
    uint256 public constant NONCE = 0;

    constructor(address gateway_) AxelarExecutable(gateway_) {}

    function _execute(
        string calldata sourceChain,
        string calldata sourceAddress,
        bytes calldata payload
    ) internal override {
        (, bytes memory payloadActual) = abi.decode(payload, (uint256, bytes));
        valueReceived = abi.decode(payloadActual, (string));
        valueSent = PONG;
        gateway.callContract(sourceChain, sourceAddress, abi.encode(NONCE, valueSent));
    }
}
