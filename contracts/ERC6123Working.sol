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
        Types.IRS memory _irs,
        uint256 _initialMarginBuffer,
        uint256 _initialTerminationFee
    ) ERC7586(_irsTokenName, _irsTokenSymbol, _irs) {
        initialMarginBuffer = _initialMarginBuffer;
        initialTerminationFee = _initialTerminationFee;
    }

    function inceptTrade(
        address _withParty,
        string memory _tradeData,
        int _position,
        int256 _paymentAmount,
        string memory _initialSettlementData
    ) external override onlyCounterparty onlyWhenTradeInactive returns (string memory) {
        address inceptor = msg.sender;

        if(inceptor == _withParty)
            revert cannotInceptWithYourself(msg.sender, _withParty);
        if(_withParty != irs.fixedRatePayer || _withParty != irs.floatingRatePayer)
            revert mustBePayerOrReceiver(_withParty, irs.fixedRatePayer, irs.floatingRatePayer);
        if(_position != 1 || _position != -1)
            revert invalidPositionValue(_position);
        if(_paymentAmount == 0) revert invalidPaymentAmount(_paymentAmount);

        tradeState = TradeState.Incepted;

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

        /**
            //The initial margin and the termination fee must be deposited into the contract
            uint256 margin = marginRequirements[msg.sender];
            uint256 marginAndFee = margin.marginBuffer + margin.terminationFee;

            require(
                IERC20(irs.settlementCurrency).transferFrom(msg.sender, address(this), marginAndFee * 1 ether),
                "Failed to to transfer the initial margin + the termination fee"
            );
            
            marginRequirements[_irs.floatingRatePayer] = Types.MarginRequirement(_initialBuffer, _initialTerminationFee);
        */
    }

    
    function confirmTrade(
        address _withParty,
        string memory _tradeData,
        int _position,
        int256 _paymentAmount,
        string memory _initialSettlementData
    ) external override onlyWhenTradeIncepted {
        address inceptingParty = otherParty();

        uint256 confirmationHash = uint256(keccak256(
            abi.encode(
                _withParty,
                msg.sender,
                _tradeData,
                -_position,
                -_paymentAmount,
                _initialSettlementData
            )
        ));

        if(pendingRequests[confirmationHash] != inceptingParty)
            revert inconsistentTradeDataOrWrongAddress(inceptingParty, confirmationHash);

        delete pendingRequests[confirmationHash];
        tradeState = TradeState.Confirmed;

        emit TradeConfirmed(msg.sender, tradeID);

        /**
            // The initial margin and the termination fee must be deposited into the contract
            uint256 margin = marginRequirements[msg.sender];
            uint256 marginAndFee = margin.marginBuffer + margin.terminationFee;

            require(
                IERC20(irs.settlementCurrency).transferFrom(msg.sender, address(this), marginAndFee * 1 ether),
                "Failed to to transfer the initial margin + the termination fee"
            );

            marginRequirements[_irs.fixedRatePayer] = Types.MarginRequirement(_initialBuffer, _initialTerminationFee);
        */
    }

    function cancelTrade(
        address _withParty,
        string memory _tradeData,
        int _position,
        int256 _paymentAmount,
        string memory _initialSettlementData
    )  override onlyWhenTradeIncepted {
        address inceptingParty = msg.sender;

        uint256 confirmationHash = uint256(keccak256(
            abi.encode(
                msg.sender,
                _withParty,
                _tradeData,
                _position,
                _paymentAmount,
                _initialSettlementData
            )
        ));

        if(pendingRequests[confirmationHash] != inceptingParty)
            revert inconsistentTradeDataOrWrongAddress(inceptingParty, confirmationHash);

        delete pendingRequests[confirmationHash];
        tradeState = TradeState.Inactive;

        emit TradeCanceled(msg.sender, tradeID);
    }

    function initiateSettlement() external {
        
    }
    
    function performSettlement(int256 settlementAmount, string memory settlementData) external {

    }


    function afterTransfer(bool success, string memory transactionData) external {

    }

    /**-> NOT CLEAR: Why requesting trade termination after the trade has been settled ? */
    function requestTradeTermination(
        string memory _tradeId,
        int256 _terminationPayment,
        string memory _terminationTerms
    ) external override onlyCounterparty onlyWhenSettled {
        if(
            keccak256(abi.encodePacked(_tradeId)) != keccak256(abi.encodePacked(tradeID))
        ) revert invalidTradeID(_tradeId);

        uint256 terminationHash = uint256(keccak256(
            abi.encode(
                _tradeId,
                "terminate",
                _terminationPayment,
                _terminationTerms
            )
        ));

        pendingRequests[terminationHash] = msg.sender;

        emit TradeTerminationRequest(msg.sender, _tradeId, _terminationPayment, _terminationTerms);
    }

    function confirmTradeTermination(
        string memory _tradeId,
        int256 _terminationPayment,
        string memory _terminationTerms
    ) external onlyCounterparty onlyWhenSettled {
        address pendingRequestParty = otherParty();

        uint256 confirmationhash = uint256(keccak256(
            abi.encode(
                _tradeId,
                "terminate",
                _terminationPayment,
                _terminationTerms
            )
        ));

        if(pendingRequests[confirmationhash] != pendingRequestParty)
            revert inconsistentTradeDataOrWrongAddress(pendingRequestParty, confirmationhash);

        delete pendingRequests[confirmationhash];
    }

    function cancelTradeTermination(
        string memory _tradeId,
        int256 _terminationPayment,
        string memory _terminationTerms
    ) external onlyWhenSettled {
        address pendingRequestParty = msg.sender;

        uint256 confirmationHash = uint256(keccak256(
            abi.encode(
                _tradeId,
                "terminate",
                _terminationPayment,
                _terminationTerms
            )
        ));

        if(pendingRequests[confirmationhash] != pendingRequestParty)
            revert inconsistentTradeDataOrWrongAddress(pendingRequestParty, confirmationhash);

        delete pendingRequests[confirmationhash];

        emit TradeTerminationCanceled(msg.sender, _tradeId, _terminationTerms);
    }

    /**---------------------- nternal Private and other view functions ----------------------*/

    function otherParty() internal view returns(address) {
        return msg.sender == irs.fixedRatePayer ? irs.floatingRatePayer : irs.fixedRatePayer;
    }

    function otherParty(address _account) internal view returns(address) {
        return _account == irs.fixedRatePayer ? irs.floatingRatePayer : irs.fixedRatePayer;
    }
}