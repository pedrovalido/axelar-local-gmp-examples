//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import {IAxelarGateway} from '@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGateway.sol';
import {IAxelarGasService} from '@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol';
import {AxelarExecutable} from '@axelar-network/axelar-gmp-sdk-solidity/contracts/executables/AxelarExecutable.sol';
import { StringToAddress, AddressToString } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/StringAddressUtils.sol';

contract PingSender is AxelarExecutable {
    using StringToAddress for string;
    using AddressToString for address;
    IAxelarGasService immutable gasReceiver;

    error NotEnoughValueForGas();

    string public thisChain;
    string public valueSent = '';
    string public valueReceived = '';
    string private constant PONG = 'PONG';
    string private constant PING = 'PING';

    constructor(address _gateway, address _gasReceiver, string memory thisChain_) AxelarExecutable(_gateway){
        gasReceiver = IAxelarGasService(_gasReceiver);
        thisChain = thisChain_;
    }

    function ping(
        string calldata destinationChain,
        string calldata destinationAddress,
        bytes calldata payload,
        uint256 gasForRemote
    ) public payable {
        bytes memory modifiedPayload = abi.encode(PONG);
        if (gasForRemote > 0) {
            if (gasForRemote > msg.value) revert NotEnoughValueForGas();
            gasReceiver.payNativeGasForContractCall{ value: gasForRemote }(
                address(this),
                destinationChain,
                destinationAddress,
                payload,
                msg.sender
            );
            
            if (msg.value > gasForRemote) {
                gasReceiver.payNativeGasForContractCall{ value: msg.value - gasForRemote }(
                    destinationAddress.toAddress(),
                    thisChain,
                    address(this).toString(),
                    modifiedPayload,
                    msg.sender
                );
            }
        }
        
        valueSent = abi.decode(payload, (string));
        gateway.callContract(destinationChain, destinationAddress, payload);
    }

    function _execute(
        string calldata sourceChain_,
        string calldata sourceAddress_,
        bytes calldata payload
    ) internal override {
        string memory message = abi.decode(payload, (string));
        valueReceived = message;
        require(keccak256(abi.encodePacked((message))) == keccak256(abi.encodePacked((PING))), 'Message should be PING');
        
        gateway.callContract(sourceChain_, sourceAddress_, abi.encode(PING));
        valueSent = PONG;

    }
}
