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
        uint256 _initialTerminationFee,
        int256 _rateMultiplier
    ) ERC7586(_irsTokenName, _irsTokenSymbol, _irs) {
        initialMarginBuffer = _initialMarginBuffer;
        initialTerminationFee = _initialTerminationFee;
        confirmationTime = 1 hours;
        rateMultiplier = _rateMultiplier;
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
        inceptingTime = block.timestamp;

        emit TradeIncepted(
            msg.sender,
            _withParty,
            tradeID,
            _tradeData,
            _position,
            _paymentAmount,
            _initialSettlementData
        );

        //The initial margin and the termination fee must be deposited into the contract
        uint256 marginAndFee = initialMarginBuffer + initialTerminationFee;

        require(
            IERC20(irs.settlementCurrency).transfer(address(this), marginAndFee * 1 ether),
            "Failed to to transfer the initial margin + the termination fee"
        );
        
        marginRequirements[msg.sender] = Types.MarginRequirement({
            marginBuffer: initialMarginBuffer,
            terminationFee: initialTerminationFee
        });
    }

    
    function confirmTrade(
        address _withParty,
        string memory _tradeData,
        int _position,
        int256 _paymentAmount,
        string memory _initialSettlementData
    ) external override onlyWhenTradeIncepted onlyWithinConfirmationTime {
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

        // The initial margin and the termination fee must be deposited into the contract
        uint256 marginAndFee = initialMarginBuffer + initialTerminationFee;

        require(
            IERC20(irs.settlementCurrency).transfer(address(this), marginAndFee * 1 ether),
            "Failed to to transfer the initial margin + the termination fee"
        );
        
        marginRequirements[msg.sender] = Types.MarginRequirement({
            marginBuffer: initialMarginBuffer,
            terminationFee: initialTerminationFee
        });
    }

    function cancelTrade(
        address _withParty,
        string memory _tradeData,
        int _position,
        int256 _paymentAmount,
        string memory _initialSettlementData
    )  override onlyWhenTradeIncepted onlyAfterConfirmationTime {
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

    /**
    * @notice In case of Chainlink ETH Staking Rate, the rateMultiplier = 3. And the result MUST be devided by 10^7
    *         We assume rates are input in basis point
    */
    function initiateSettlement() external onlyCounterparty onlyWhenTradeConfirmed {
        tradeState = TradeState.Valuation;

        string memory settlementData = Strings.toString(netSettlementAmount);

        emit SettlementRequested(msg.sender, tradeData, settlementData);
    }
    
    function performSettlement(
        int256 _settlementAmount,
        string memory _settlementData
    ) external onlyWhenValuation {
        int256 fixedRate = irs.swapRate * rateMultiplier;
        int256 floatingRate = benchmark() + irs.spread * rateMultiplier;

        tradeState = TradeState.InTransfer;

        if(fixedRate == floatingRate) {
            revert nothingToSwap(fixedRate, floatingRate);
        } else if(fixedRate > floatingRate) {
            netSettlementAmount = fixedRate * irs.notionalAmount - floatingRate * irs.notionalAmount;
            receivingParty = irs.floatingRatePayer;

            // Needed just to check the input settlement amount
            require(
                netSettlementAmount == uint256(_settlementAmount),
                "invalid settlement amount"
            );

            // Generates the settlement receipt
            irsReceipt.push(
                Types.IRSReceipt({
                    from: irs.fixedRatePayer,
                    to: receivingParty,
                    amount: netSettlementAmount
                })
            );
        } else {
            netSettlementAmount = floatingRate * irs.notionalAmount - fixedRate * irs.notionalAmount;
            receivingParty = irs.fixedRatePayer;

            // Needed just to check the input settlement amount
            require(
                netSettlementAmount == uint256(_settlementAmount),
                "invalid settlement amount"
            );

            // Generates the settlement receipt
            irsReceipt.push(
                Types.IRSReceipt({
                    from: irs.floatingRatePayer,
                    to: receivingParty,
                    amount: netSettlementAmount
                })
            );
        }

        emit SettlementEvaluated(msg.sender, netSettlementAmount, _settlementData);
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

    /**---------------------- Internal Private and other view functions ----------------------*/
    function getInitialMargin() external view returns(uint256) {
        return initialMarginBuffer;
    }

    function getInitialTerminationFee() external view returns(uint256) {
        return initialTerminationFee;
    }

    function getMarginRequirement(address _account) external view returns(Types.MarginRequirement) {
        return marginRequirements[_account];
    }

    function getRateMultiplier() external view returns(uint8) {
        return rateMultiplier;
    }

    function otherParty() internal view returns(address) {
        return msg.sender == irs.fixedRatePayer ? irs.floatingRatePayer : irs.fixedRatePayer;
    }

    function otherParty(address _account) internal view returns(address) {
        return _account == irs.fixedRatePayer ? irs.floatingRatePayer : irs.fixedRatePayer;
    }
}