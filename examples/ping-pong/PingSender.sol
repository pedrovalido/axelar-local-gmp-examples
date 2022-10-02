//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import {IAxelarGateway} from '@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGateway.sol';
import {IAxelarGasService} from '@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol';
import {AxelarExecutable} from '@axelar-network/axelar-gmp-sdk-solidity/contracts/executables/AxelarExecutable.sol';

contract PingSender is AxelarExecutable {
    IAxelarGasService immutable gasReceiver;

    string public valueSent = '';
    string public valueReceived = '';
    string private constant PONG = 'PONG';
    string private constant PING = 'PING';

    constructor(address _gateway, address _gasReceiver) AxelarExecutable(_gateway){
        gasReceiver = IAxelarGasService(_gasReceiver);
    }

    function ping(
        string calldata destinationChain,
        string calldata destinationAddress,
        string memory message
    ) public payable {
        bytes memory payload = abi.encode(message);
        if (msg.value > 0) {
            gasReceiver.payNativeGasForContractCall{value: msg.value}(
                address(this),
                destinationChain,
                destinationAddress,
                payload,
                msg.sender
            );
        }
        valueSent = message;
        gateway.callContract(destinationChain, destinationAddress, payload);
    }

    function _execute(
        string calldata sourceChain_,
        string calldata sourceAddress_,
        bytes calldata payload
    ) internal override {
        string memory message = abi.decode(payload, (string));
        require(keccak256(abi.encodePacked((message))) == keccak256(abi.encodePacked((PING))), 'Message should be PING');
        valueReceived = message;
        
        //send pong back to source address
        ping(sourceChain_, sourceAddress_, PONG);
    }
}
