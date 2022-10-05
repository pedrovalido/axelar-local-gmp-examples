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

    mapping(uint256 => string) public valueSent;
    mapping(uint256 => string) public valueReceived;

    string public constant PING = 'PING';
    string public constant PONG = 'PONG';

    IAxelarGasService public immutable gasReceiver;
    string public thisChain;
    uint256 public nonce;

    constructor(
        address gateway_,
        address gasReceiver_,
        string memory thisChain_
    ) AxelarExecutable(gateway_) {
        gasReceiver = IAxelarGasService(gasReceiver_);
        thisChain = thisChain_;
    }

    function getValueSent() external view returns (string memory) {
        return valueSent[nonce];
    }

    function getValueReceived() external view returns (string memory) {
        return valueReceived[nonce];
    }

    function ping(
        string calldata destinationChain,
        string calldata destinationAddress,
        bytes calldata payload,
        uint256 gasForRemote
    ) external payable {
        string memory message = abi.decode(payload, (string));
        nonce++;
        uint256 nonce_ = nonce;
        bytes memory modifiedPayload = abi.encode(nonce_, payload);

        if (gasForRemote > 0) {
            if (gasForRemote > msg.value) revert NotEnoughValueForGas();
            gasReceiver.payNativeGasForContractCall{ value: gasForRemote }(
                address(this),
                destinationChain,
                destinationAddress,
                modifiedPayload,
                msg.sender
            );
            if (msg.value > gasForRemote) {
                gasReceiver.payNativeGasForContractCall{ value: msg.value - gasForRemote }(
                    destinationAddress.toAddress(),
                    thisChain,
                    address(this).toString(),
                    abi.encode(nonce_, PONG),
                    msg.sender
                );
            }
        }

        valueSent[nonce] = message;
        gateway.callContract(destinationChain, destinationAddress, modifiedPayload);
    }

    function _execute(
        string calldata, /*sourceChain*/
        string calldata, /*sourceAddress*/
        bytes calldata payload
    ) internal override {
        (, string memory message) = abi.decode(payload, (uint256, string));
        valueReceived[nonce] = message;
        valueReceived[nonce - 1] = '';
        valueSent[nonce - 1] = '';
    }
}
