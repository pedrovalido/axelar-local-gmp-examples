// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import { AxelarExecutable } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/executables/AxelarExecutable.sol';
import { IAxelarGateway } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGateway.sol';
import { IAxelarGasService } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol';
import { StringToAddress, AddressToString } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/StringAddressUtils.sol';

contract PingSender is AxelarExecutable {
    using StringToAddress for string;
    using AddressToString for address;

    error NotEnoughValueForGas();

    string public valueSent = '';
    string public valueReceived = '';

    string public constant PING = 'PING';
    string public constant PONG = 'PONG';
    uint256 public constant NONCE = 0;
    IAxelarGasService public immutable gasReceiver;
    string public thisChain;

    constructor(
        address gateway_,
        address gasReceiver_,
        string memory thisChain_
    ) AxelarExecutable(gateway_) {
        gasReceiver = IAxelarGasService(gasReceiver_);
        thisChain = thisChain_;
    }

    function ping(
        string calldata destinationChain,
        string calldata contractAddress,
        bytes calldata payload,
        uint256 gasForRemote
    ) external payable {
        bytes memory modifiedPayload = abi.encode(NONCE, payload);

        if (gasForRemote > 0) {
            if (gasForRemote > msg.value) revert NotEnoughValueForGas();
            gasReceiver.payNativeGasForContractCall{ value: gasForRemote }(
                address(this),
                destinationChain,
                contractAddress,
                modifiedPayload,
                msg.sender
            );
            if (msg.value > gasForRemote) {
                gasReceiver.payNativeGasForContractCall{ value: msg.value - gasForRemote }(
                    contractAddress.toAddress(),
                    thisChain,
                    address(this).toString(),
                    abi.encode(NONCE, PONG),
                    msg.sender
                );
            }
        }

        valueSent = abi.decode(payload, (string));
        gateway.callContract(destinationChain, contractAddress, modifiedPayload);
    }

    function _execute(
        string calldata, /*sourceChain*/
        string calldata, /*sourceAddress*/
        bytes calldata payload
    ) internal override {
        (, string memory message) = abi.decode(payload, (uint256, string));
        valueReceived = message;
    }
}
