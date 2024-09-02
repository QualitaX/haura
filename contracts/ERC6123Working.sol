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
        uint256 _rateMultiplier
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

        if(_position == 1) {
            irs.fixedRatePayer = msg.sender;
            irs.floatingRatePayer = _withParty;
        } else {
            irs.fixedRatePayer = _withParty;
            irs.floatingRatePayer = msg.sender;
        }

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

        marginRequirements[msg.sender] = Types.MarginRequirement({
            marginBuffer: initialMarginBuffer,
            terminationFee: initialTerminationFee
        });

        //The initial margin and the termination fee must be deposited into the contract
        uint256 marginAndFee = initialMarginBuffer + initialTerminationFee;

        require(
            IERC20(irs.settlementCurrency).transfer(address(this), marginAndFee * 1 ether),
            "Failed to to transfer the initial margin + the termination fee"
        );
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

        marginRequirements[msg.sender] = Types.MarginRequirement({
            marginBuffer: initialMarginBuffer,
            terminationFee: initialTerminationFee
        });

        // The initial margin and the termination fee must be deposited into the contract
        uint256 marginAndFee = initialMarginBuffer + initialTerminationFee;

        require(
            IERC20(irs.settlementCurrency).transfer(address(this), marginAndFee * 1 ether),
            "Failed to to transfer the initial margin + the termination fee"
        );
    }

    function cancelTrade(
        address _withParty,
        string memory _tradeData,
        int _position,
        int256 _paymentAmount,
        string memory _initialSettlementData
    ) external override onlyWhenTradeIncepted onlyAfterConfirmationTime {
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

    function initiateSettlement() external override onlyCounterparty onlyWhenTradeConfirmed {
        tradeState = TradeState.Valuation;

        emit SettlementRequested(msg.sender, tradeData, settlementData[settlementData.length - 1]);
    }
    
    /**
    * @notice In case of Chainlink ETH Staking Rate, the rateMultiplier = 3. And the result MUST be devided by 10^7
    *         We assume rates are input in basis point
    */
    function performSettlement(
        int256 _settlementAmount,
        string memory _settlementData
    ) external override onlyWhenValuation {
        int256 fixedRate = irs.swapRate;
        int256 floatingRate = benchmark() + irs.spread;

        tradeState = TradeState.Settled;

        if(fixedRate == floatingRate) {
            revert nothingToSwap(fixedRate, floatingRate);
        } else if(fixedRate > floatingRate) {
            netSettlementAmount = uint256(fixedRate) * irs.notionalAmount - uint256(floatingRate) * irs.notionalAmount;
            receiverParty = irs.floatingRatePayer;
            payerParty = irs.fixedRatePayer;

            // Needed just to check the input settlement amount
            require(
                netSettlementAmount == uint256(_settlementAmount),
                "invalid settlement amount"
            );

            // Generates the settlement receipt
            irsReceipt.push(
                Types.IRSReceipt({
                    from: irs.fixedRatePayer,
                    to: receiverParty,
                    amount: netSettlementAmount,
                    timestamp: block.timestamp
                })
            );
        } else {
            netSettlementAmount = uint256(floatingRate) * irs.notionalAmount - uint256(fixedRate) * irs.notionalAmount;
            receiverParty = irs.fixedRatePayer;
            payerParty = irs.floatingRatePayer;

            // Needed just to check the input settlement amount
            require(
                netSettlementAmount == uint256(_settlementAmount),
                "invalid settlement amount"
            );

            // Generates the settlement receipt
            irsReceipt.push(
                Types.IRSReceipt({
                    from: irs.floatingRatePayer,
                    to: receiverParty,
                    amount: netSettlementAmount,
                    timestamp: block.timestamp
                })
            );
        }

        _checkBalanceAndSwap(payerParty, netSettlementAmount);

        emit SettlementEvaluated(msg.sender, int256(netSettlementAmount), _settlementData);
    }

    /**
    * @notice We don't implement the after transfer function since the transfer of the contract
    *         net present value is transferred in the `performSettlement function`.
    */
    function afterTransfer(bool /**success*/, string memory /*transactionData*/) external pure override {
        revert obseleteFunction();
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

        if(pendingRequests[confirmationHash] != pendingRequestParty)
            revert inconsistentTradeDataOrWrongAddress(pendingRequestParty, confirmationHash);

        delete pendingRequests[confirmationHash];

        emit TradeTerminationCanceled(msg.sender, _tradeId, _terminationTerms);
    }

    /**----------------------------- Transacctional functions --------------------------------*/
    /**
    * @notice Make a CALL to ERC-7586 swap function. Check that the payer has enough initial
    *         margin to make the transfer in case of insufficient balance during settlement
    * @param _payer The swap payer account address
    * @param _settlementAmount The net settlement amount to be transferred (in ether unit)
    */
    function _checkBalanceAndSwap(address _payer, uint256 _settlementAmount) private {
         uint256 balance = IERC20(irs.settlementCurrency).balanceOf(_payer);

         if (balance < _settlementAmount) {
            uint256 buffer = marginRequirements[_payer].marginBuffer;

            if(buffer < _settlementAmount) {
                revert notEnoughMarginBuffer(_settlementAmount, buffer);
            } else {
                marginRequirements[_payer].marginBuffer = buffer - _settlementAmount;
                transferMode = 1;

                swap();

                transferMode = 0;
            }
         } else {
            swap();
         }
    }

    /**---------------------- Internal Private and other view functions ----------------------*/
    function getInitialMargin() external view returns(uint256) {
        return initialMarginBuffer;
    }

    function getInitialTerminationFee() external view returns(uint256) {
        return initialTerminationFee;
    }

    function getMarginRequirement(address _account) external view returns(Types.MarginRequirement memory) {
        return marginRequirements[_account];
    }

    function getRateMultiplier() external view returns(uint256) {
        return rateMultiplier;
    }

    function otherParty() internal view returns(address) {
        return msg.sender == irs.fixedRatePayer ? irs.floatingRatePayer : irs.fixedRatePayer;
    }

    function otherParty(address _account) internal view returns(address) {
        return _account == irs.fixedRatePayer ? irs.floatingRatePayer : irs.fixedRatePayer;
    }
}