// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import { AxelarExecutable } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/executables/AxelarExecutable.sol';
import { IAxelarGateway } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGateway.sol';

contract PingReceiver is AxelarExecutable {
    string public constant PING = 'PING';
    string public constant PONG = 'PONG';

    mapping(uint256 => string) public valueSent;
    mapping(uint256 => string) public valueReceived;
    uint256 public nonce;

    constructor(address gateway_) AxelarExecutable(gateway_) {}

    function getValueSent() external view returns (string memory) {
        return valueSent[nonce];
    }

    function getValueReceived() external view returns (string memory) {
        return valueReceived[nonce];
    }

    function _execute(
        string calldata sourceChain,
        string calldata sourceAddress,
        bytes calldata payload
    ) internal override {
        (uint256 nonce_, bytes memory payloadActual) = abi.decode(payload, (uint256, bytes));
        valueReceived[nonce] = '';
        valueSent[nonce] = '';
        nonce = nonce + 1;
        valueSent[nonce] = PONG;
        string memory message = abi.decode(payloadActual, (string));
        valueReceived[nonce] = message;
        gateway.callContract(sourceChain, sourceAddress, abi.encode(nonce_, PONG));
    }
}
