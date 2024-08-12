// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/Strings.sol";

import "./interfaces/IERC6123.sol";
import "./ERC6123Storage.sol";

contract ERC6123 is IERC6123, ERC6123Storage {
    constructor (address _party1, address _party2) {
        party1 = _party1;
        party2 = _party2;
    }

    function inceptTrade(
        address _withParty,
        string memory _tradeData,
        int _position,
        int256 _paymentAmount,
        string memory _initialSettlementData
    ) external override onlyCounterparty onlyWhenTradeInactive() returns (string memory) {
        if(msg.sender == _withParty) revert cannotInceptWithYourself(msg.sender, _withParty);
        if(_position != 1 || _position != -1) revert invalidPositionValue(_position);

        tradeState = TradeState.Incepted;

        uint256 dataHash = uint256(
            keccak256(
                abi.encode(
                    msg.sender,
                    _withParty,
                    _tradeData,
                    _position,
                    _paymentAmount,
                    _initialSettlementData
                )
            )
        );

        pendingRequests[dataHash] = msg.sender;
        tradeID = Strings.toString(dataHash);
        tradeData = _tradeData;
        receivingParty = _position == 1 ? msg.sender : _withParty;

        emit TradeIncepted(
            msg.sender,
            _withParty,
            tradeId,
            _tradeData,
            _position,
            _paymentAmount,
            _initialSettlementData
        );
    }

    function confirmTrade(
        address withParty,
        string memory tradeData,
        int position,
        int256 paymentAmount,
        string memory initialSettlementData
    ) external onlyCounterparty onlyWhenTradeIncepted {
        address inceptingParty = _inceptingParty();

        uint256 dataHash = uint256(
            keccak256(
                abi.encode(
                    _withParty,
                    msg.sender,
                    _tradeData,
                    -_position,
                    -_paymentAmount,
                    _initialSettlementData
                )
            )
        );

        if(pendingRequests[dataHash] != inceptingParty)
            revert inconsistentTradeDataOrWrongAddress(inceptingParty, dataHash);

        delete pendingRequests[dataHash];
        tradeState = TradeState.Confirmed;

        emit TradeConfirmed(msg.sender, tradeID);
     }

    function cancelTrade(
        address withParty,
        string memory tradeData,
        int position,
        int256 paymentAmount,
        string memory initialSettlementData
    ) external {

    }

    function initiateSettlement() external {
        
    }

    function performSettlement(
        int256 settlementAmount,
        string memory settlementData
    ) external {
        
    }

    function afterTransfer(
        bool success,
        string memory transactionData
    ) external {

    }

    function requestTradeTermination(
        string memory tradeId,
        int256 terminationPayment,
        string memory terminationTerms
    ) external {

    }

    function confirmTradeTermination(
        string memory tradeId,
        int256 terminationPayment,
        string memory terminationTerms
    ) external {

    }

    function cancelTradeTermination(
        string memory tradeId,
        int256 terminationPayment,
        string memory terminationTerms
    ) external {

    }

    function _inceptingParty() private view returns(address) {
        return msg.sender == party1 ? party2 : party1;
    }
}