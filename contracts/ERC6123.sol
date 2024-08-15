// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/Strings.sol";

import "./interfaces/IERC6123.sol";
import "./ERC6123Storage.sol";
import "./assets/ERC7586.sol";
import "./Types.sol";

/**
* @notice Implementation of ERC6123 for Interest Rate Swap Derivatives
* @author Samuel Gwlanold Edoumou - QualitaX
* - The contract implements the Vanilla Interest Rate Swap to exchange fixed and floating interest rates
*/
contract ERC6123 is IERC6123, ERC6123Storage, ERC7586 {
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
    ) external override onlyCounterparty onlyWhenTradeInactive returns (string memory) {
        if(_withParty != irs.fixedRatePayer || _withParty != irs.floatingRatePayer)
            revert mustBePayerOrReceiver(_withParty, irs.fixedRatePayer, irs.floatingRatePayer);
        if(msg.sender == _withParty)
            revert cannotInceptWithYourself(msg.sender, _withParty);
        if(_position != 1 || _position != -1)
            revert invalidPositionValue(_position);

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
        upfrontPayment = _position == 1 ? _paymentAmount : -_paymentAmount;

        emit TradeIncepted(
            msg.sender,
            _withParty,
            tradeId,
            _tradeData,
            _position,
            _paymentAmount,
            _initialSettlementData
        );

        return tradeID;
    }

    function confirmTrade(
        address _withParty,
        string memory _tradeData,
        int _position,
        int256 _paymentAmount,
        string memory _initialSettlementData
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

        address upfrontPayer = upfrontPayment > 0 ? otherParty(receivingParty) : receivingParty;
        uint256 upfrontTransferAmount = uint256(abs(_paymentAmount));

        // processTradeAfterConfirmation(upfrontPayer, upfrontTransferAmount, _initialSettlementData);
     }

    function cancelTrade(
        address _withParty,
        string memory _tradeData,
        int _position,
        int256 _paymentAmount,
        string memory _initialSettlementData
    ) external {
        address inceptingParty = msg.sender;
        uint256 dataHash = uint256(
            keccak256(abi.encode(
                msg.sender,
                _withParty,
                _tradeData,
                _position,
                _paymentAmount,
                _initialSettlementData
            ))
        );

        require(
            pendingRequests[dataHash] == inceptingParty,
            "Failed: inconsistent trade data or wrong party address"
        );

        delete pendingRequests[dataHash];
        tradeState = TradeState.Inactive;

        emit TradeCanceled(msg.sender, tradeID);
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
        string memory _tradeId,
        int256 _terminationPayment,
        string memory _terminationTerms
    ) external {
        require(
            keccak256(abi.encodePacked(tradeID)) == keccak256(abi.encodePacked(tradeID)),
            "Trade ID mismatch"
        );
        uint256 hash = uint256(
            keccak256(abi.encode(
                _tradeId,
                "terminate",
                _terminationPayment,
                _terminationTerms
            ))
        );

        pendingRequests[hash] = msg.sender;

        emit TradeTerminationRequest(msg.sender, _tradeId, _terminationPayment, _terminationTerms);
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
        return msg.sender == _irs.floatingRatePayer ? _irs.fixedRatePayer : _irs.floatingRatePayer;
    }

    /**
     * Other party
     */
    function otherParty(address _party) internal view returns(address) {
        return _party == irs.floatingRatePayer ? irs.fixedRatePayer : irs.floatingRatePayer;
    }

    /**
     * Maximum value of two integers
     */
    function max(int a, int b) internal pure returns (int256) {
        return a > b ? a : b;
    }

    /**
    * Minimum value of two integers
    */
    function min(int a, int b) internal pure returns (int256) {
        return a < b ? a : b;
    }

    /**
     * Absolute value of an integer
     */
    function abs(int x) internal pure returns (int256) {
        return x >= 0 ? x : -x;
    }

}