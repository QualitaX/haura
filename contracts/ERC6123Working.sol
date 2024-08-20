// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/Strings.sol";

import "./interfaces/IERC6123.sol";
import "./ERC6123StorageWorking.sol";
import "./assets/ERC7586.sol";
import "./Types.sol";

contract ERC6123Working is IERC6123, ERC6123StorageWorking, ERC7586 {
    modifier onlyCounterparty() {
        require(
            msg.sender == irs.fixedRatePayer || msg.sender == irs.floatingRatePayer,
            "You are not a counterparty."
        );
        _;
    }

    constructor (
        string memory _irsTokenName,
        string memory _irsTokenSymbol,
        Types.IRS memory _irs
    ) ERC7586(_irsTokenName, _irsTokenSymbol, _irs) {}

    function inceptTrade(
        address _withParty,
        string memory _tradeData,
        int _position,
        int256 _paymentAmount,
        string memory _initialSettlementData
    ) external onlyCounterparty onlyWhenTradeInactive returns (string memory) {
        address inceptor = msg.sender;

        if(inceptor == _withParty)
            revert cannotInceptWithYourself(msg.sender, _withParty);
        if(_withParty != irs.fixedRatePayer || _withParty != irs.floatingRatePayer)
            revert mustBePayerOrReceiver(_withParty, irs.fixedRatePayer, irs.floatingRatePayer);
        if(_position != 1 || _position != -1)
            revert invalidPositionValue(_position);
        if(_paymentAmount == 0) revert invalidPaymentAmount(_paymentAmount);

        uint256 dataHash = uint256(keccak256(
            abi.encode(
                msg.sender,
                _withParty,
                _tradeData,
                _position,
                _paymentAmount,
                _initialSettlementData
            )
        ));

        pendingRequests[dataHash] = msg.sender;
        tradeID = Strings.toString(dataHash);
        tradeData = _tradeData;

        receivingParty = _position == 1 ? mas.sender : _withParty;
        upfrontPayment = _position == 1 ? _paymentAmount : -_paymentAmount;

        emit TradeIncepted(
            msg.sender,
            _withParty,
            tradeID, _tradeData,
            _position,
            _paymentAmount,
            _initialSettlementData
        );
    }

    
    function confirmTrade(address withParty, string memory tradeData, int position, int256 paymentAmount, string memory initialSettlementData) external {

    }

    function cancelTrade(address withParty, string memory tradeData, int position, int256 paymentAmount, string memory initialSettlementData) external {

    }

    function initiateSettlement() external {
        
    }
    
    function performSettlement(int256 settlementAmount, string memory settlementData) external {

    }


    function afterTransfer(bool success, string memory transactionData) external {

    }

    function requestTradeTermination(string memory tradeId, int256 terminationPayment, string memory terminationTerms) external {

    }

    function confirmTradeTermination(string memory tradeId, int256 terminationPayment, string memory terminationTerms) external {

    }

    function cancelTradeTermination(string memory tradeId, int256 terminationPayment, string memory terminationTerms) external {

    }
}