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
            tradeID,
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

        processTradeAfterConfirmation(upfrontPayer, upfrontTransferAmount, _initialSettlementData);
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
        if ( inStateConfirmed()){
            if (success){
                setTradeState(TradeState.Settled);
                emit TradeActivated(getTradeID());
            }
            else{
                setTradeState(TradeState.Terminated);
                emit TradeTerminated(tradeID, "Upfront Transfer Failure");
            }
        }
        else if ( inStateTransfer() ){
            if (success){
                setTradeState(TradeState.Settled);
                emit SettlementTransferred("Settlement Settled - Pledge Transfer");
            }
            else{  // Settlement & Pledge Case: transferAmount is transferred from SDC balance (i.e. pledged balance).
                int256 settlementAmount = settlementAmounts[settlementAmounts.length-1];
                setTradeState(TradeState.InTermination);
                processTerminationWithPledge(settlementAmount);
                emit TradeTerminated(tradeID, "Settlement Failed - Pledge Transfer");
            }
        }
        else if( inStateTermination() ){
            if (success){
                setTradeState(TradeState.Terminated);
                emit TradeTerminated(tradeID, "Trade terminated sucessfully");
            }
            else{
                emit TradeTerminated(tradeID, "Mutual Termination failed - Pledge Transfer");
                processTerminationWithPledge(getTerminationPayment());
            }
        }
        else
            revert("Trade State does not allow to call 'afterTransfer'");
    }

    function requestTradeTermination(
        string memory _tradeId,
        int256 _terminationPayment,
        string memory _terminationTerms
    ) external {
        require(
            keccak256(abi.encodePacked(tradeID)) == keccak256(abi.encodePacked(_tradeId)),
            "Trade ID mismatch"
        );
        uint256 terminationHash = uint256(
            keccak256(abi.encode(
                _tradeId,
                "terminate",
                _terminationPayment,
                _terminationTerms
            ))
        );

        pendingRequests[terminationHash] = msg.sender;

        emit TradeTerminationRequest(msg.sender, _tradeId, _terminationPayment, _terminationTerms);
    }

    function confirmTradeTermination(
        string memory _tradeId,
        int256 _terminationPayment,
        string memory _terminationTerms
    ) external {
        address pendingRequestParty = _inceptingParty();
        uint256 hashConfirm = uint256(
            keccak256(abi.encode(
                _tradeId,
                "terminate",
                -_terminationPayment,
                _terminationTerms
            ))
        );
        require(
            pendingRequests[hashConfirm] == pendingRequestParty,
            "Confirmation failed due to wrong party or missing request"
        );

        delete pendingRequests[hashConfirm];
        terminationPayment = msg.sender == receivingParty ? _terminationPayment : -_terminationPayment;

        emit TradeTerminationConfirmed(msg.sender, _tradeId, _terminationPayment, _terminationTerms);

        // Trigger Termination Payment Amount
        address payerAddress = terminationPayment > 0 ? otherParty(receivingParty) : receivingParty;
        uint256 absPaymentAmount = uint256(abs(_terminationPayment));
        setTradeState(TradeState.InTermination);
        processTradeAfterMutualTermination(payerAddress, absPaymentAmount, _terminationTerms);
    }

    function cancelTradeTermination(
        string memory _tradeId,
        int256 _terminationPayment,
        string memory _terminationTerms
    ) external {
        address pendingRequestParty = msg.sender;
        uint256 hashConfirm = uint256(keccak256(
            abi.encode(
                _tradeId,
                "terminate",
                _terminationPayment,
                _terminationTerms
            )
        ));
        require(
            pendingRequests[hashConfirm] == pendingRequestParty,
            "Cancellation failed due to wrong party or missing request"
        );
        delete pendingRequests[hashConfirm];
        
        emit TradeTerminationCanceled(msg.sender, _tradeId, _terminationTerms);
    }

    /*
     * Booking of the upfrontPayment and implementation specific setups of margin buffers / wallets.
     */
    function processTradeAfterConfirmation(address _upfrontPayer, uint256 _upfrontPayment, string memory _initialSettlementData) internal virtual {

    }


    /*
     * Booking of the terminationAmount and implementation specific cleanup of margin buffers / wallets.
     */
    function processTradeAfterMutualTermination(address _terminationFeePayer, uint256 _terminationAmount,  string memory _terminationData) internal virtual {

    }

    function _inceptingParty() private view returns(address) {
        return msg.sender == _irs.floatingRatePayer ? _irs.fixedRatePayer : _irs.floatingRatePayer;
    }

    /*
     * Management of Trade States
     */
    function    inStateIncepted()    public view returns (bool) { return tradeState == TradeState.Incepted; }
    function    inStateConfirmed()   public view returns (bool) { return tradeState == TradeState.Confirmed; }
    function    inStateSettled()     public view returns (bool) { return tradeState == TradeState.Settled; }
    function    inStateTransfer()    public view returns (bool) { return tradeState == TradeState.InTransfer; }
    function    inStateTermination() public view returns (bool) { return tradeState == TradeState.InTermination; }
    function    inStateTerminated()  public view returns (bool) { return tradeState == TradeState.Terminated; }

    function getTradeState() public view returns (TradeState) {
        return tradeState;
    }

    function setTradeState(TradeState newState) internal {
        if ( newState == TradeState.Incepted && tradeState != TradeState.Inactive)
            revert("Provided Trade state is not allowed");
        if ( newState == TradeState.Confirmed && tradeState != TradeState.Incepted)
            revert("Provided Trade state is not allowed");
        if ( newState == TradeState.InTransfer && !(tradeState == TradeState.Confirmed || tradeState == TradeState.Valuation) )
            revert("Provided Trade state is not allowed");
        if ( newState == TradeState.Valuation && tradeState != TradeState.Settled)
            revert("Provided Trade state is not allowed");
        if ( newState == TradeState.InTermination && !(tradeState == TradeState.InTransfer || tradeState == TradeState.Settled ) )
            revert("Provided Trade state is not allowed");
        tradeState = newState;
    }

    /*
     * Upfront and termination payments.
     */

    function getReceivingParty() public view returns (address) {
        return receivingParty;
    }

    function getUpfrontPayment() public view returns (int) {
        return upfrontPayment;
    }

    function getTerminationPayment() public view returns (int) {
        return terminationFee;
    }

    /*
     * Trade Specification (ID, Token, Data)
     */

    function getTradeID() public view returns (string memory) {
        return tradeID;
    }

    function setTradeId(string memory _tradeID) public {
        tradeID= _tradeID;
    }

    function getTradeData() public view returns (string memory) {
        return tradeData;
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